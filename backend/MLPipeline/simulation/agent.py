"""
SmartphoneUser — Mesa agent representing one synthetic person.

Behavior is driven by:
  - persona id           (from personas.PERSONAS)
  - latent UserProfile   (sampled trait vector — drives utilities)
  - internal state       (energy, hunger, boredom, social_need)
  - environment / time   (current hour, weekday/weekend, POIs)

The episode FSM in episodic.py decides multi-step plans; this class only
glues state, telemetry generation, and episode-engine ticking together.
"""

from __future__ import annotations

import random
import logging
from typing import Optional, Dict, List

import numpy as np
import mesa

import config
import utils
import personas
import realism

logger = logging.getLogger(__name__)


class SmartphoneUser(mesa.Agent):
    """One synthetic smartphone user with a persona-conditioned profile."""

    def __init__(self, unique_id: int, model, persona_id: Optional[str] = None):
        super().__init__(unique_id, model)

        # ---- persona / latent profile ----
        self.persona_id: str = persona_id or personas.sample_persona_id()
        self.profile: personas.UserProfile = personas.make_user_profile(self.persona_id)

        # ---- fixed locations (assigned once at init) ----
        self._assign_locations()

        # ---- mutable position ----
        self.current_location: dict = self.home_poi
        self.latitude: float = self.home_poi["latitude"]
        self.longitude: float = self.home_poi["longitude"]

        # ---- internal state (0..100) — initialized with mild persona offset ----
        # Energy starts higher for routine-stable agents
        self.energy = float(np.clip(70 + 20 * self.profile.routine_stability + np.random.normal(0, 5), 30, 100))
        self.boredom = float(np.clip(np.random.normal(20, 10), 0, 100))
        self.social_need = float(np.clip(60 * self.profile.social_need + np.random.normal(0, 8), 0, 100))
        self.hunger = float(np.clip(np.random.normal(30, 10), 0, 100))

        # ---- behavioral state ----
        self.current_activity = "idle"
        self.current_app: Optional[str] = None
        self.screen_on: bool = False
        self.in_transit: bool = False

        # ---- episode FSM ----
        self.current_episode = None     # episodic.Episode
        self.episode_engine = None      # episodic.EpisodeEngine
        self.is_episode_locked: bool = False
        self.episode_history: List[Dict] = []

        # tally screen time on the user object so we can write daily summaries
        self._screen_minutes_today: float = 0.0
        self._last_summary_day: int = -1

        # GPS derivation state
        self._prev_lat: float = self.latitude
        self._prev_lon: float = self.longitude
        self._dwell_anchor_lat: float = self.latitude
        self._dwell_anchor_lon: float = self.longitude
        self._dwell_anchor_tick: int = 0  # tick when dwell window started

        # Realism upgrade models (pack A)
        self.gps_quality = realism.GPSQualityModel()
        self.device_state = realism.DeviceImperfectionModel()

        # Hierarchical planner — current daily plan (Level 2)
        self.daily_plan = None              # planner.DailyPlan
        self._daily_plan_date = None        # date this plan was made for

    # ------------------------------------------------------------------ init
    def _assign_locations(self):
        """Pick home, work/school, and a personal POI ring."""
        rng = random
        pois = self.model.pois

        # Home
        self.home_poi = self._pick_poi("HOME") or self._fallback_poi("HOME")

        # Work / School (mutually exclusive based on profile)
        if self.profile.study_intensity > self.profile.work_intensity:
            self.work_poi = self._pick_poi("SCHOOL", near=self.home_poi,
                                           radius_km=self.profile.mobility_radius_km) \
                            or self._pick_poi("WORK") \
                            or self._fallback_poi("SCHOOL")
        else:
            self.work_poi = self._pick_poi("WORK", near=self.home_poi,
                                           radius_km=self.profile.mobility_radius_km) \
                            or self._fallback_poi("WORK")

        # Personal favorite leisure POIs (limited by mobility radius)
        leisure_cats = ["CAFE", "PARK", "SHOPPING", "GYM", "NIGHTLIFE", "LANDMARK"]
        self.leisure_pois = []
        for cat in leisure_cats:
            poi = self._pick_poi(cat, near=self.home_poi, radius_km=self.profile.mobility_radius_km)
            if poi is not None:
                self.leisure_pois.append(poi)

        # Gym specifically — sporcus need a guaranteed gym
        gyms = self.model.pois.get("GYM", [])
        if gyms and self.profile.exercise_propensity > 0.5:
            # bias toward a closer gym
            ranked = sorted(
                gyms,
                key=lambda p: utils.haversine_distance(
                    self.home_poi["latitude"], self.home_poi["longitude"],
                    p["latitude"], p["longitude"])
            )
            self.gym_poi = ranked[0]
        else:
            self.gym_poi = rng.choice(gyms) if gyms else None

    def _pick_poi(self, category: str, near: Optional[dict] = None,
                  radius_km: float = 999) -> Optional[dict]:
        """Pick a POI of a given category, optionally constrained by radius."""
        pois = self.model.pois.get(category, [])
        if not pois:
            return None
        if near is None:
            return random.choice(pois)
        candidates = []
        for p in pois:
            d_km = utils.haversine_distance(
                near["latitude"], near["longitude"], p["latitude"], p["longitude"]
            ) / 1000
            if d_km <= radius_km:
                candidates.append(p)
        if not candidates:
            return random.choice(pois)
        return random.choice(candidates)

    def _fallback_poi(self, category: str) -> dict:
        """Synthesize a placeholder POI within bounds."""
        lat, lon = utils.generate_random_location_in_bounds()
        return {
            "id": f"{category}_{self.unique_id}_synthetic",
            "name": f"{category.title()} {self.unique_id}",
            "latitude": lat, "longitude": lon, "type": category,
        }

    # ----------------------------------------------------------------- step
    def step(self):
        """One simulation tick."""
        # 0. Refresh daily plan if we crossed midnight
        self._maybe_refresh_daily_plan()

        # 1. Update base internal-state dynamics (decay/recovery)
        self._update_internal_states_base()

        # 2. Episode FSM
        if self.is_episode_locked and self.episode_engine and self.current_episode:
            cont = self.episode_engine.tick()
            if not cont:
                self._finalize_episode()
                self._decide_next_episode()
        else:
            self._decide_next_episode()

        # 2b. Realism models — tick after episode FSM so in_transit is current
        self.gps_quality.tick(self.model.current_tick, self)
        self.device_state.tick(self.model.current_tick, self)

        # 3. Telemetry
        self._generate_events()

    # ------------------------------------------------------ internal states
    def _update_internal_states_base(self):
        """Per-tick decay and recovery (overridden by episode step effects)."""
        act = self.current_activity

        # ENERGY ---------------------------------------------------
        if act in ("sleep",):
            self.energy = utils.clamp(self.energy + config.ENERGY_RECOVERY_SLEEP, max_val=100.0)
        elif act in ("relax_at_home", "idle", "home_relax", "RELAX_AT_HOME"):
            self.energy = utils.clamp(self.energy + config.ENERGY_RECOVERY_REST, max_val=100.0)
        else:
            self.energy = utils.clamp(self.energy - config.ENERGY_DECAY_ACTIVE * 0.6, max_val=100.0)

        # BOREDOM --------------------------------------------------
        if act in ("idle", "stay_idle"):
            self.boredom = utils.clamp(self.boredom + config.BOREDOM_INCREMENT_IDLE, max_val=100.0)
        else:
            self.boredom = utils.clamp(self.boredom + 0.1, max_val=100.0)

        # SOCIAL NEED ----------------------------------------------
        if act == "sleep" or self.current_location is self.home_poi:
            self.social_need = utils.clamp(self.social_need - config.SOCIAL_NEED_DECAY_FAMILY, max_val=100.0)
        else:
            base_inc = config.SOCIAL_NEED_INCREMENT * (0.5 + self.profile.social_need)
            self.social_need = utils.clamp(self.social_need + base_inc, max_val=100.0)

        # HUNGER ---------------------------------------------------
        self.hunger = utils.clamp(self.hunger + config.HUNGER_INCREMENT, max_val=100.0)

    def _maybe_refresh_daily_plan(self):
        """Re-plan once per simulated day."""
        today = self.model.current_datetime.date()
        if today != self._daily_plan_date:
            planner = getattr(self.model, "planner", None)
            if planner is not None:
                self.daily_plan = planner.plan_day(self, self.model.current_datetime.weekday())
            self._daily_plan_date = today

    # ------------------------------------------------------ episode control
    def _decide_next_episode(self):
        """Pick next episode using utility-based selection from the manager."""
        from episodic import EpisodeManager, EpisodeEngine

        manager = EpisodeManager(self)
        episode = manager.decide_episode()
        if episode is None:
            from episodic import _create_relax_at_home_episode
            episode = _create_relax_at_home_episode(self)

        self.current_episode = episode
        self.episode_engine = EpisodeEngine(episode, self)
        self.is_episode_locked = True
        self.current_activity = episode.name

    def _finalize_episode(self):
        """Apply episode-level state deltas, log the episode, reset FSM."""
        ep = self.current_episode
        if ep is None:
            return

        # Apply final state deltas
        for state_name, delta in ep.state_effects.items():
            cur = getattr(self, state_name, None)
            if cur is None:
                continue
            setattr(self, state_name, utils.clamp(cur + delta, max_val=100.0))

        # Log
        entry = {
            "user_id": self.unique_id,
            "persona": self.persona_id,
            "episode_id": ep.episode_id,
            "episode_name": ep.name,
            "start_tick": ep.start_tick,
            "end_tick": self.model.current_tick,
            "duration_ticks": self.model.current_tick - ep.start_tick,
            "rationale": getattr(ep, "rationale", ""),
            "steps_completed": "|".join(self.episode_engine.steps_completed) if self.episode_engine else "",
        }
        self.episode_history.append(entry)
        self.model.add_episode_log(entry)

        # Reset
        self.current_episode = None
        self.episode_engine = None
        self.is_episode_locked = False
        self.current_activity = "idle"

    # -------------------------------------------------------- telemetry gen
    def _generate_events(self):
        """Emit GPS / app / screen telemetry consistent with current episode step."""
        # Pull context from current episode step
        step = None
        apps_for_step: List[str] = []
        generates_events = True
        if self.episode_engine and self.current_episode:
            step = self.episode_engine.get_current_step()
            if step:
                apps_for_step = step.apps_used
                generates_events = step.generates_events

        # NOTE: per-tick state dynamics are handled by step.on_tick callbacks
        # to avoid double-counting with episode.state_effects (applied once at
        # finalize). step.state_effects is reserved for one-shot exit deltas.

        # ---- GPS ping (subsampled with dropout + variable accuracy) ----
        gps_every = max(1, config.GPS_SAMPLING_INTERVAL_MINUTES // config.TICK_DURATION_MINUTES)
        if self.model.current_tick % gps_every == 0:
            # Always advance the prev-position tracker (maintains speed calc even across gaps)
            prev_lat, prev_lon = self._prev_lat, self._prev_lon
            self._prev_lat = self.latitude
            self._prev_lon = self.longitude

            # Gate: device must allow GPS and quality model must emit a ping this tick
            if (self.device_state.can_record_gps(self.model.current_tick) and
                    self.gps_quality.should_emit_ping(self.model.current_tick, gps_every)):

                # Variable noise by GPS mode and movement state
                noise_std = self.gps_quality.effective_noise_m(self.in_transit)
                lat_n, lon_n = utils.add_gps_noise(self.latitude, self.longitude, noise_std)
                accuracy = self.gps_quality.reported_accuracy_m(noise_std)

                # Speed: distance since last true position / fixed 10-min window
                interval_s = config.GPS_SAMPLING_INTERVAL_MINUTES * 60
                moved_m = utils.haversine_distance(prev_lat, prev_lon, self.latitude, self.longitude)
                speed_mps = moved_m / max(1, interval_s)

                # Dwell update: reset anchor if moved >50m
                anchor_drift_m = utils.haversine_distance(
                    self._dwell_anchor_lat, self._dwell_anchor_lon,
                    self.latitude, self.longitude
                )
                if anchor_drift_m > 50.0:
                    self._dwell_anchor_lat = self.latitude
                    self._dwell_anchor_lon = self.longitude
                    self._dwell_anchor_tick = self.model.current_tick
                dwell_s = (self.model.current_tick - self._dwell_anchor_tick) \
                    * config.TICK_DURATION_MINUTES * 60

                # Movement state from speed thresholds (m/s)
                if speed_mps < 0.3:
                    movement_state = "stationary"
                elif speed_mps < 1.8:
                    movement_state = "walking"
                elif speed_mps < 5.0:
                    movement_state = "cycling"
                elif speed_mps < 14.0:
                    movement_state = "transit"
                else:
                    movement_state = "vehicle"

                self.model.add_gps_ping(
                    self.unique_id, lat_n, lon_n,
                    accuracy_m=accuracy,
                    speed_mps=speed_mps,
                    dwell_time_s=dwell_s,
                    movement_state=movement_state,
                    gps_mode=self.gps_quality.mode,
                )

        # ---- screen events (gated by device online state) ----
        if self.device_state.can_record_screen(self.model.current_tick):
            if self.current_episode and self.current_episode.name == "SLEEP":
                night_browse = (random.random() < 0.05 * self.profile.digital_addiction)
                if not night_browse and self.screen_on:
                    self.screen_on = False
                    self.model.add_screen_event(self.unique_id, "off")
                    self.model.add_screen_event(self.unique_id, "lock")
                elif night_browse and not self.screen_on:
                    self.screen_on = True
                    self.model.add_screen_event(self.unique_id, "on")
                    self.model.add_screen_event(self.unique_id, "unlock")
            elif not generates_events:
                # Non-event step (shower, prep): screen mostly off
                if self.screen_on and random.random() < 0.3:
                    self.screen_on = False
                    self.model.add_screen_event(self.unique_id, "lock")
            else:
                # Normal step: stochastic unlock driven by digital_addiction
                unlock_prob = 0.4 + 0.4 * self.profile.digital_addiction
                if not self.screen_on and random.random() < unlock_prob:
                    self.screen_on = True
                    self.model.add_screen_event(self.unique_id, "on")
                    self.model.add_screen_event(self.unique_id, "unlock")

        # ---- app session (lognormal duration + device gating) ----
        if (self.screen_on and generates_events and apps_for_step and
                self.device_state.can_record_app(self.model.current_tick)):
            chosen = self._pick_app(apps_for_step)
            if chosen:
                meta = config.APPS[chosen]
                cat = meta["category"]

                # UPGRADE 1: lognormal per-category duration (replaces uniform(lo,hi))
                scale = max(0.3, 0.7 + 0.3 * (self.profile.screen_time_target_h / 6.0))
                duration = realism.AppSessionSampler.sample_duration(cat, scale)
                # UPGRADE 3: possible background-process truncation
                duration = self.device_state.truncate_session(duration, self.model.current_tick)

                # Foreground/background heuristic (unchanged from original)
                step_type = step.step_type if step else ""
                background = False
                if cat == "music" and step_type in ("travel", "workout", "warmup", "cooldown", "study", "work"):
                    background = (random.random() < 0.7)
                elif cat == "fitness" and step_type in ("workout", "warmup", "cooldown"):
                    background = (random.random() < 0.5)
                elif cat == "music":
                    background = (random.random() < 0.3)

                self.model.add_app_session(
                    self.unique_id, chosen, cat, duration,
                    foreground=not background,
                )
                self._screen_minutes_today += duration if not background else 0
                if not background:
                    self.current_app = chosen

                # Notification bursts (unchanged)
                self._maybe_emit_notifications(apps_for_step)

                # UPGRADE 1b: micro-burst — rapid unlock-check-dismiss loops
                burst_p = realism.AppSessionSampler.micro_burst_prob(self.profile.digital_addiction)
                if random.random() < burst_p:
                    self._emit_micro_burst(apps_for_step)

    def _maybe_emit_notifications(self, candidate_apps: List[str]):
        """
        Emit a small burst of notifications driven by:
          - social_need / digital_addiction (more notifications for heavy users)
          - which messaging/social apps are in the current step's candidate list
        Bursts are 1-4 events of type 'notification', tagged with the source app.
        """
        # base probability per tick of receiving any notification at all
        base_p = 0.15 + 0.35 * self.profile.digital_addiction \
                 + 0.20 * self.profile.social_need
        if random.random() > base_p:
            return

        # pick notification source from social/messaging apps in this step
        sources = [
            a for a in candidate_apps
            if a in config.APPS and config.APPS[a]["category"] in ("messaging", "social")
        ]
        if not sources:
            sources = [a for a in self.profile.app_weights.keys()
                       if config.APPS.get(a, {}).get("category") in ("messaging", "social")]
        if not sources:
            return

        # weight sources by user app_weights so heavy WhatsApp users get WhatsApp notifs
        weights = np.array([self.profile.app_weights.get(a, 0.1) for a in sources])
        weights = weights / weights.sum()

        # burst size — small for most, occasional bigger spike
        burst = 1 + int(np.random.geometric(0.6) - 1)
        burst = min(burst, 4)
        for _ in range(burst):
            app = str(np.random.choice(sources, p=weights))
            self.model.add_screen_event(self.unique_id, "notification", app=app)

    def _emit_micro_burst(self, candidate_apps: List[str]):
        """
        Rapid unlock-check-dismiss loop: 1-3 very short additional sessions.
        Models real behavior where users quickly open an app, glance, and close —
        interspersed around a main engagement session.
        """
        if not self.device_state.can_record_app(self.model.current_tick):
            return
        n = random.randint(1, 3)
        for _ in range(n):
            app = self._pick_app(candidate_apps)
            if not app:
                continue
            duration = realism.AppSessionSampler.sample_micro_session()
            cat = config.APPS[app]["category"]
            self.model.add_app_session(self.unique_id, app, cat, duration, foreground=True)
            # Each micro-burst triggers its own lock/unlock pair
            if self.device_state.can_record_screen(self.model.current_tick):
                self.model.add_screen_event(self.unique_id, "unlock")
                self.model.add_screen_event(self.unique_id, "lock")

    def _pick_app(self, candidate_apps: List[str]) -> Optional[str]:
        """
        Sample an app from the step's candidate list, weighted by the user's
        personal app preferences. This is what makes a Gamer's SOCIALIZE lean
        Discord while a Sosyal's SOCIALIZE leans Instagram, even though both
        share the candidate pool.
        """
        if not candidate_apps:
            return None
        weights = []
        present = []
        for a in candidate_apps:
            if a in self.profile.app_weights:
                weights.append(self.profile.app_weights[a])
                present.append(a)
        if not present:
            return random.choice(candidate_apps)
        weights = np.array(weights, dtype=float)
        weights = weights / weights.sum()
        return str(np.random.choice(present, p=weights))

    # -------------------------------------------------------- introspection
    def hour_of_day(self) -> int:
        return self.model.current_datetime.hour
