"""
Episodic Behavior Engine
========================

An *episode* is a coherent multi-step behavior the agent commits to (a "mini
plan"). Each step inside an episode is an FSM state with:
  - duration in ticks
  - per-tick state effects (energy, hunger, social_need, boredom)
  - a list of *candidate apps* (the agent's profile then chooses among them)
  - on_enter / on_tick / on_exit callbacks for movement & location handling

The engine keeps the agent locked into the active episode until it finishes,
which produces realistic time-extended behavior instead of independent per-tick
actions.

The EpisodeManager scores all available episode types using utility functions
that read directly from the agent's UserProfile latent traits. No persona-name
ifs — utility is a pure function of (state, time, profile, environment), so two
agents from the same persona behave similarly without being identical.

Episode catalog (15):
  SLEEP                NIGHT_BROWSING       MORNING_ROUTINE
  COMMUTE_TO_WORK      COMMUTE_HOME         WORK_DAY
  STUDY_BLOCK          GO_TO_CAFE           SOCIALIZE
  EXERCISE             RELAX_AT_HOME        CONTENT_BINGE
  GAMING_MARATHON      ERRAND_CHAIN         EXPLORATION_DAY
"""

from __future__ import annotations

import random
import logging
from dataclasses import dataclass, field
from typing import Optional, Dict, List, Callable

import numpy as np

import config
import utils

logger = logging.getLogger(__name__)


# ============================================================================
# 1. EPISODE STEP & EPISODE
# ============================================================================

@dataclass
class EpisodeStep:
    name: str
    duration_ticks: int
    step_type: str
    on_enter: Optional[Callable] = None
    on_tick: Optional[Callable] = None
    on_exit: Optional[Callable] = None
    generates_events: bool = True
    state_effects: Dict[str, float] = field(default_factory=dict)
    apps_used: List[str] = field(default_factory=list)

    def execute_enter(self, agent):
        if self.on_enter:
            self.on_enter(agent, self)

    def execute_tick(self, agent, progress: int):
        if self.on_tick:
            self.on_tick(agent, self, progress)

    def execute_exit(self, agent):
        if self.on_exit:
            self.on_exit(agent, self)


@dataclass
class Episode:
    episode_id: str
    name: str
    description: str
    steps: List[EpisodeStep]
    total_duration_ticks: int
    state_effects: Dict[str, float] = field(default_factory=dict)
    priority: float = 1.0
    location_required: Optional[str] = None
    start_tick: int = -1
    rationale: str = ""


# ============================================================================
# 2. EPISODE ENGINE  (FSM executor)
# ============================================================================

class EpisodeEngine:
    def __init__(self, episode: Episode, agent):
        self.episode = episode
        self.agent = agent
        self.current_step_index = 0
        self.step_progress_ticks = 0
        self.is_active = True
        self.steps_completed: List[str] = []
        if self.episode.steps:
            self.episode.steps[0].execute_enter(agent)

    def get_current_step(self) -> Optional[EpisodeStep]:
        if 0 <= self.current_step_index < len(self.episode.steps):
            return self.episode.steps[self.current_step_index]
        return None

    def tick(self) -> bool:
        if not self.is_active:
            return False
        step = self.get_current_step()
        if step is None:
            self.is_active = False
            return False
        step.execute_tick(self.agent, self.step_progress_ticks)
        self.step_progress_ticks += 1
        if self.step_progress_ticks >= step.duration_ticks:
            step.execute_exit(self.agent)
            self.steps_completed.append(step.name)
            self.current_step_index += 1
            self.step_progress_ticks = 0
            nxt = self.get_current_step()
            if nxt is None:
                self.is_active = False
                return False
            nxt.execute_enter(self.agent)
        return True


# ============================================================================
# 3. UTILITY HELPERS — used by every episode utility
# ============================================================================

def _circadian_match(agent, target_hour_low: float, target_hour_high: float,
                     bonus: float = 30.0) -> float:
    """Bonus when current hour is within target window (mod 24)."""
    h = agent.model.get_current_hour()
    if target_hour_low <= target_hour_high:
        if target_hour_low <= h < target_hour_high:
            return bonus
    else:
        # wraps midnight
        if h >= target_hour_low or h < target_hour_high:
            return bonus
    return 0.0


def _wraps_midnight_window(target_low: float, target_high: float, h: float) -> bool:
    if target_low <= target_high:
        return target_low <= h < target_high
    return h >= target_low or h < target_high


def _hour_distance(h1: float, h2: float) -> float:
    """Smallest hour distance modulo 24."""
    d = abs(h1 - h2) % 24
    return min(d, 24 - d)


# ============================================================================
# 4. EPISODE MANAGER  (persona-conditioned utility selection)
# ============================================================================

# Episodes in the catalog and their factory names. The manager scores them all.
EPISODE_TYPES = [
    "SLEEP", "NIGHT_BROWSING", "MORNING_ROUTINE",
    "COMMUTE_TO_WORK", "COMMUTE_HOME", "WORK_DAY", "STUDY_BLOCK",
    "GO_TO_CAFE", "SOCIALIZE", "EXERCISE",
    "RELAX_AT_HOME", "CONTENT_BINGE", "GAMING_MARATHON",
    "ERRAND_CHAIN", "EXPLORATION_DAY",
]


class EpisodeManager:
    """Scores every episode and softmax-samples one based on agent profile."""

    def __init__(self, agent):
        self.agent = agent
        self.profile = agent.profile
        self.model = agent.model

    # ---------------------------------------------------------- entry point
    def decide_episode(self) -> Optional[Episode]:
        utilities: Dict[str, float] = {}
        rationales: Dict[str, str] = {}
        for ep_type in EPISODE_TYPES:
            score, why = self._score_episode(ep_type)
            utilities[ep_type] = score
            rationales[ep_type] = why

        # Apply hierarchical daily-theme multipliers (Level 2)
        plan = getattr(self.agent, "daily_plan", None)
        theme = "ROUTINE"
        if plan is not None:
            theme = plan.theme
            for ep_type in list(utilities.keys()):
                utilities[ep_type] *= plan.multiplier_for(ep_type)

        # Softmax sampling, with low temperature for routine-stable agents
        temperature = 1.5 + 1.5 * (1.0 - self.profile.routine_stability)
        episode_type = self._softmax_pick(utilities, temperature)

        ep = create_episode_instance(episode_type, self.agent)
        if ep is not None:
            base_reason = rationales.get(episode_type, "")
            ep.rationale = f"theme={theme}; {base_reason}"
        return ep

    # -------------------------------------------------------------- scoring
    def _score_episode(self, ep_type: str) -> tuple[float, str]:
        """Return (utility, short reason string)."""
        a = self.agent
        p = self.profile
        h = self.model.get_current_hour() + self.model.current_datetime.minute / 60.0
        weekend = self.model.is_weekend()
        energy_r = a.energy / 100.0
        bored_r = a.boredom / 100.0
        soc_r = a.social_need / 100.0
        hung_r = a.hunger / 100.0

        # -------------- SLEEP -------------------------------------------
        if ep_type == "SLEEP":
            # Want to sleep when (a) close to typical sleep hour or (b) energy crashed.
            d = _hour_distance(h, p.sleep_hour)
            # very strong pull when within an hour of typical sleep hour
            if d <= 1.0:
                base = 200 - 30 * d
            elif d <= 3.0:
                base = 90 - 20 * d
            else:
                base = max(0.0, 30 - 5 * d)
            if a.energy < config.ENERGY_THRESHOLD_SLEEP:
                base += 80
            # don't sleep right after waking
            if _hour_distance(h, p.wake_hour) < 1.5:
                base = 0.0
            return max(0.0, base), f"sleep_dist_h={d:.1f} energy={a.energy:.0f}"

        # -------------- NIGHT_BROWSING ----------------------------------
        if ep_type == "NIGHT_BROWSING":
            if a.current_location is not a.home_poi:
                return 0.0, "not home"
            # only in the ~1h window right *before* typical sleep
            in_window = _wraps_midnight_window(
                (p.sleep_hour - 1.5) % 24, p.sleep_hour, h
            )
            if not in_window:
                return 0.0, "outside night window"
            score = 15 + 60 * p.digital_addiction
            score += 15 * p.content_consumption
            # Don't compete with sleep itself
            if a.energy < config.ENERGY_THRESHOLD_SLEEP:
                score = 0.0
            return score, f"digital_addiction={p.digital_addiction:.2f}"

        # -------------- MORNING_ROUTINE ---------------------------------
        if ep_type == "MORNING_ROUTINE":
            # Right after typical wake_hour
            d = _hour_distance(h, p.wake_hour)
            if d > 2.0:
                return 0.0, "not morning"
            if a.current_location is not a.home_poi:
                return 0.0, "not at home"
            score = 80 - 30 * d
            score += 20 * p.routine_stability
            return max(0.0, score), f"wake_dist={d:.1f}"

        # -------------- COMMUTE_TO_WORK ---------------------------------
        if ep_type == "COMMUTE_TO_WORK":
            if not p.weekday_work or weekend:
                return 0.0, "no commute on weekend / non-worker"
            if a.current_location is a.work_poi:
                return 0.0, "already at work"
            commute_window_low = (p.wake_hour + 0.3) % 24
            commute_window_high = (p.wake_hour + 3.0) % 24
            if not _wraps_midnight_window(commute_window_low, commute_window_high, h):
                return 0.0, "outside commute window"
            score = 80 + 30 * max(p.work_intensity, p.study_intensity)
            return score, "morning commute"

        # -------------- COMMUTE_HOME ------------------------------------
        if ep_type == "COMMUTE_HOME":
            if a.current_location is not a.work_poi:
                return 0.0, "not at work"
            depart_low = (p.wake_hour + 8) % 24
            depart_high = (p.wake_hour + 13) % 24
            if not _wraps_midnight_window(depart_low, depart_high, h):
                return 0.0, "too early to leave"
            return 90.0, "leaving work"

        # -------------- WORK_DAY ----------------------------------------
        if ep_type == "WORK_DAY":
            if not p.weekday_work or weekend:
                return 0.0, "no work today"
            if p.work_intensity < 0.2:
                return 0.0, "not a worker"
            if a.current_location is not a.work_poi:
                return 0.0, "not at work"
            # broader work window: 1.5 to 12 hours after typical wake
            work_start = (p.wake_hour + 1.5) % 24
            work_end = (p.wake_hour + 12) % 24
            if not _wraps_midnight_window(work_start, work_end, h):
                return 0.0, "outside work hours"
            score = 80 + 80 * p.work_intensity
            if energy_r < 0.3:
                score -= 30
            return max(0.0, score), f"work_intensity={p.work_intensity:.2f}"

        # -------------- STUDY_BLOCK -------------------------------------
        if ep_type == "STUDY_BLOCK":
            if p.study_intensity < 0.3:
                return 0.0, "not a studier"
            if not (9 <= h < 23):
                return 0.0, "outside study window"
            # students study at school during school hours, anywhere otherwise
            if a.current_location is a.work_poi:
                score = 80 + 60 * p.study_intensity
            elif a.current_location is a.home_poi:
                score = 30 + 60 * p.study_intensity
            else:
                return 0.0, "not at study location"
            if weekend:
                score *= 0.6
            if energy_r < 0.3:
                score -= 25
            return max(0.0, score), f"study={p.study_intensity:.2f}"

        # -------------- GO_TO_CAFE --------------------------------------
        if ep_type == "GO_TO_CAFE":
            if not (10 <= h < 23):
                return 0.0, "outside cafe hours"
            score = 10
            if hung_r > 0.6:
                score += 35
            score += 25 * p.social_need
            score += 15 * (1 - p.home_centeredness)
            if weekend:
                score += 15
            return score, f"hunger={hung_r:.2f} social={p.social_need:.2f}"

        # -------------- SOCIALIZE ---------------------------------------
        if ep_type == "SOCIALIZE":
            if not (12 <= h < 26 or h < 2):
                return 0.0, "outside social hours"
            score = 0
            if soc_r > 0.5:
                score += 60 * (soc_r - 0.5) * 2
            score += 35 * p.social_need
            if weekend:
                score += 20
            score += 15 * (1 - p.home_centeredness)
            return max(0.0, score), f"social_need_state={soc_r:.2f}"

        # -------------- EXERCISE ----------------------------------------
        if ep_type == "EXERCISE":
            if a.gym_poi is None:
                return 0.0, "no gym"
            in_morning = 5 <= h < 9
            in_evening = 17 <= h < 21
            if not (in_morning or in_evening):
                return 0.0, "outside workout window"
            score = 10 + 70 * p.exercise_propensity
            if energy_r < 0.4:
                score -= 30
            if weekend and p.exercise_propensity > 0.6:
                score += 10
            return max(0.0, score), f"exercise_propensity={p.exercise_propensity:.2f}"

        # awake-window check: only allow long leisure episodes when the user
        # is normally awake (between wake_hour and sleep_hour-1)
        active = p.is_active_hour(int(h))

        # -------------- RELAX_AT_HOME -----------------------------------
        if ep_type == "RELAX_AT_HOME":
            if not active:
                return 0.0, "asleep window"
            if a.current_location is not a.home_poi:
                return 0.0, "not home"
            score = 5 + 25 * p.home_centeredness
            if energy_r < 0.4:
                score += 20
            if 16 <= h < 23:
                score += 15
            if weekend:
                score += 10
            # don't compete with work/study/commute windows
            if p.weekday_work and not weekend and (p.wake_hour + 1.5) % 24 <= h < (p.wake_hour + 11) % 24:
                score *= 0.3
            return score, "leisure"

        # -------------- CONTENT_BINGE -----------------------------------
        if ep_type == "CONTENT_BINGE":
            if not active:
                return 0.0, "asleep window"
            if a.current_location is not a.home_poi:
                return 0.0, "not home"
            score = 5 + 50 * p.content_consumption
            # boost only during evening leisure window
            if 18 <= h < 23:
                score += 25
            if energy_r < 0.5:
                score += 10
            if weekend:
                score += 15
            score += 10 * p.home_centeredness
            # weekday workers don't binge during work hours
            if p.weekday_work and not weekend and (p.wake_hour + 1.5) % 24 <= h < (p.wake_hour + 11) % 24:
                score *= 0.2
            return max(0.0, score), f"content={p.content_consumption:.2f}"

        # -------------- GAMING_MARATHON ---------------------------------
        if ep_type == "GAMING_MARATHON":
            if p.gaming_propensity < 0.3 or not active:
                return 0.0, "not a gamer / asleep"
            if a.current_location is not a.home_poi:
                return 0.0, "not home"
            score = 5 + 80 * p.gaming_propensity
            if 18 <= h < 24 or (h < 3 and p.chronotype > 0.4):
                score += 20
            if weekend:
                score += 15
            if energy_r < 0.3:
                score -= 25
            if p.weekday_work and not weekend and (p.wake_hour + 1.5) % 24 <= h < (p.wake_hour + 11) % 24:
                score *= 0.3
            return max(0.0, score), f"gaming={p.gaming_propensity:.2f}"

        # -------------- ERRAND_CHAIN ------------------------------------
        if ep_type == "ERRAND_CHAIN":
            # multi-stop shopping/banking — rare per day
            if not (10 <= h < 19):
                return 0.0, "outside errand hours"
            score = 5 + 25 * (1 - p.home_centeredness)
            if weekend:
                score += 20
            if a._has_done_today("ERRAND_CHAIN"):
                score = max(0.0, score - 40)
            return max(0.0, score), "errands"

        # -------------- EXPLORATION_DAY ---------------------------------
        if ep_type == "EXPLORATION_DAY":
            if not (10 <= h < 20):
                return 0.0, "outside exploration window"
            score = 0 + 80 * p.explore_propensity
            if weekend:
                score += 15
            score -= 30 * p.home_centeredness
            if a._has_done_today("EXPLORATION_DAY"):
                score -= 60
            return max(0.0, score), f"explore={p.explore_propensity:.2f}"

        return 0.0, ""

    # -------------------------------------------------------- softmax pick
    @staticmethod
    def _softmax_pick(utilities: Dict[str, float], temperature: float) -> str:
        names = list(utilities.keys())
        scores = np.array([utilities[n] for n in names], dtype=float)
        if scores.sum() <= 0:
            return "RELAX_AT_HOME"
        scaled = scores / max(temperature, 1e-3)
        scaled -= scaled.max()
        exps = np.exp(scaled)
        # zero out true-zero utilities so they cannot be picked
        exps[scores <= 0] = 0
        if exps.sum() == 0:
            return "RELAX_AT_HOME"
        probs = exps / exps.sum()
        return str(np.random.choice(names, p=probs))


# Keep a per-agent "today's episodes" cache to avoid spamming exploration.
# Lives on the agent itself.
def _has_done_today(self) -> Callable:
    pass


def _agent_has_done_today(agent, episode_name: str) -> bool:
    today = agent.model.current_datetime.date()
    for entry in agent.episode_history[-30:]:
        try:
            ep_date = utils.tick_to_datetime(entry["start_tick"]).date()
        except Exception:
            continue
        if ep_date == today and entry["episode_name"] == episode_name:
            return True
    return False


# Inject helper onto the agent class lazily (avoids circular imports)
def _install_helpers():
    from agent import SmartphoneUser
    SmartphoneUser._has_done_today = lambda self, ep: _agent_has_done_today(self, ep)


# ============================================================================
# 5. EPISODE FACTORIES
# ============================================================================

# ---- shared helpers -------------------------------------------------------

def _travel_ticks(agent, dest: dict) -> tuple[int, float]:
    """Return (#ticks, distance meters) from current pos to dest."""
    distance = utils.haversine_distance(
        agent.latitude, agent.longitude,
        dest["latitude"], dest["longitude"]
    )
    speed = agent.profile.transit_pref_speed
    if distance < 600:
        speed = config.WALKING_SPEED_M_PER_MIN
    elif distance > 6000:
        speed = max(config.DRIVING_SPEED_M_PER_MIN, agent.profile.transit_pref_speed)
    ticks = max(1, int(distance / speed / config.TICK_DURATION_MINUTES))
    return ticks, distance


def _make_travel_step(agent, dest: dict, name: str = "travel",
                      apps: Optional[List[str]] = None,
                      energy_cost: float = -3) -> EpisodeStep:
    ticks, _ = _travel_ticks(agent, dest)
    apps = apps if apps is not None else config.apps_in_categories("navigation", "music", "messaging")

    def on_enter(a, step):
        a.in_transit = True
        a._travel_start = (a.latitude, a.longitude)
        a._travel_dest = (dest["latitude"], dest["longitude"])

    def on_tick(a, step, progress):
        f = (progress + 1) / step.duration_ticks
        f = min(1.0, f)
        a.latitude = a._travel_start[0] + (a._travel_dest[0] - a._travel_start[0]) * f
        a.longitude = a._travel_start[1] + (a._travel_dest[1] - a._travel_start[1]) * f

    def on_exit(a, step):
        a.in_transit = False
        a.latitude = dest["latitude"]
        a.longitude = dest["longitude"]
        a.current_location = dest

    return EpisodeStep(
        name=name, duration_ticks=ticks, step_type="travel",
        on_enter=on_enter, on_tick=on_tick, on_exit=on_exit,
        generates_events=True, apps_used=apps,
        state_effects={"energy": energy_cost},
    )


def _episode(agent, name: str, steps: List[EpisodeStep],
             state_effects: Optional[Dict[str, float]] = None,
             priority: float = 1.0,
             location_required: Optional[str] = None,
             description: str = "") -> Episode:
    return Episode(
        episode_id=f"{name.lower()}_{agent.unique_id}_{agent.model.current_tick}",
        name=name,
        description=description or name,
        steps=steps,
        total_duration_ticks=sum(s.duration_ticks for s in steps),
        state_effects=state_effects or {},
        priority=priority,
        location_required=location_required,
        start_tick=agent.model.current_tick,
    )


# ---- 1. SLEEP -------------------------------------------------------------

def _create_sleep_episode(agent) -> Episode:
    duration_h = agent.profile.sleep_duration_h + np.random.normal(0, 0.3)
    duration_ticks = max(36, int(duration_h * config.TICKS_PER_HOUR))

    def on_enter_sleep(a, step):
        a.latitude = a.home_poi["latitude"]
        a.longitude = a.home_poi["longitude"]
        a.current_location = a.home_poi
        a.screen_on = False

    def on_tick_sleep(a, step, progress):
        a.energy = utils.clamp(a.energy + 0.4, max_val=100.0)

    steps = [
        EpisodeStep(name="prepare_bed", duration_ticks=2, step_type="prepare",
                    generates_events=False, apps_used=[]),
        EpisodeStep(name="sleep", duration_ticks=duration_ticks, step_type="sleep",
                    on_enter=on_enter_sleep, on_tick=on_tick_sleep,
                    generates_events=False, apps_used=[]),
        EpisodeStep(name="wake", duration_ticks=1, step_type="wake",
                    generates_events=True,
                    apps_used=config.apps_in_categories("messaging", "social", "news")),
    ]
    return _episode(agent, "SLEEP", steps,
                    state_effects={"energy": 60, "boredom": -10, "hunger": 25},
                    priority=2.0, location_required="HOME",
                    description="Night sleep")


# ---- 2. NIGHT_BROWSING ----------------------------------------------------

def _create_night_browsing_episode(agent) -> Episode:
    """Late-night phone scroll session in bed; doesn't really move position."""
    duration = max(3, int(np.random.normal(8, 3)))
    apps = config.apps_in_categories("short_video", "social", "video", "messaging")

    def on_tick(a, step, progress):
        a.boredom = utils.clamp(a.boredom - 0.5, max_val=100.0)
        a.energy = utils.clamp(a.energy - 0.3, max_val=100.0)

    steps = [EpisodeStep(name="scroll", duration_ticks=duration, step_type="scroll",
                         on_tick=on_tick, generates_events=True, apps_used=apps,
                         state_effects={"boredom": -5})]
    return _episode(agent, "NIGHT_BROWSING", steps,
                    state_effects={"boredom": -5, "energy": -5},
                    priority=1.0, location_required="HOME",
                    description="Pre-sleep phone scroll")


# ---- 3. MORNING_ROUTINE ---------------------------------------------------

def _create_morning_routine_episode(agent) -> Episode:
    """Wake, check phone, breakfast/news, get ready."""
    apps_news = config.apps_in_categories("news", "messaging", "social")

    def on_eat(a, step, progress):
        a.hunger = utils.clamp(a.hunger - 6, max_val=100.0)

    steps = [
        EpisodeStep(name="check_phone", duration_ticks=2, step_type="phone",
                    generates_events=True, apps_used=apps_news,
                    state_effects={"boredom": -1}),
        EpisodeStep(name="breakfast", duration_ticks=4, step_type="eat",
                    on_tick=on_eat, generates_events=True,
                    apps_used=config.apps_in_categories("news", "messaging"),
                    state_effects={"hunger": -25}),
        EpisodeStep(name="get_ready", duration_ticks=4, step_type="ready",
                    generates_events=False, apps_used=[]),
    ]
    return _episode(agent, "MORNING_ROUTINE", steps,
                    state_effects={"hunger": -25, "energy": 5},
                    priority=1.5, location_required="HOME",
                    description="Wake-up rhythm")


# ---- 4. COMMUTE_TO_WORK ---------------------------------------------------

def _create_commute_to_work_episode(agent) -> Episode:
    travel = _make_travel_step(agent, agent.work_poi, name="commute",
                               apps=config.apps_in_categories("navigation", "music", "messaging", "news", "social"))
    arrive = EpisodeStep(name="arrive", duration_ticks=1, step_type="arrive",
                         generates_events=False, apps_used=[])
    return _episode(agent, "COMMUTE_TO_WORK", [travel, arrive],
                    state_effects={"energy": -5},
                    priority=1.5, description="Going to work/school")


# ---- 5. COMMUTE_HOME ------------------------------------------------------

def _create_commute_home_episode(agent) -> Episode:
    travel = _make_travel_step(agent, agent.home_poi, name="commute_home",
                               apps=config.apps_in_categories("navigation", "music", "video", "social"))
    arrive = EpisodeStep(name="arrive_home", duration_ticks=1, step_type="arrive",
                         generates_events=False, apps_used=[])
    return _episode(agent, "COMMUTE_HOME", [travel, arrive],
                    state_effects={"energy": -5},
                    priority=1.5, description="Going home")


# ---- 6. WORK_DAY ----------------------------------------------------------

def _create_work_day_episode(agent) -> Episode:
    """3 work blocks separated by short breaks and a lunch."""
    work_apps = config.apps_in_categories("productivity", "browser", "messaging")
    break_apps = config.apps_in_categories("messaging", "social", "short_video")
    lunch_apps = config.apps_in_categories("messaging", "social", "shopping")

    def work_tick(a, step, progress):
        a.energy = utils.clamp(a.energy - 0.5, max_val=100.0)
        a.boredom = utils.clamp(a.boredom + 0.2, max_val=100.0)

    def lunch_tick(a, step, progress):
        a.hunger = utils.clamp(a.hunger - 5, max_val=100.0)

    steps = [
        EpisodeStep(name="settle_in", duration_ticks=2, step_type="settle",
                    generates_events=True, apps_used=work_apps,
                    state_effects={}),
        EpisodeStep(name="morning_block", duration_ticks=24, step_type="work",
                    on_tick=work_tick, generates_events=True,
                    apps_used=work_apps, state_effects={"energy": -15}),
        EpisodeStep(name="coffee_break", duration_ticks=3, step_type="break",
                    generates_events=True, apps_used=break_apps,
                    state_effects={"boredom": -3}),
        EpisodeStep(name="midday_block", duration_ticks=12, step_type="work",
                    on_tick=work_tick, generates_events=True,
                    apps_used=work_apps, state_effects={"energy": -10}),
        EpisodeStep(name="lunch", duration_ticks=10, step_type="lunch",
                    on_tick=lunch_tick, generates_events=True,
                    apps_used=lunch_apps, state_effects={"hunger": -25}),
        EpisodeStep(name="afternoon_block", duration_ticks=24, step_type="work",
                    on_tick=work_tick, generates_events=True,
                    apps_used=work_apps, state_effects={"energy": -15}),
        EpisodeStep(name="wrap_up", duration_ticks=4, step_type="wrap",
                    generates_events=True, apps_used=work_apps,
                    state_effects={"energy": -3}),
    ]
    return _episode(agent, "WORK_DAY", steps,
                    state_effects={"energy": -55, "boredom": 8, "hunger": -25},
                    priority=2.0, location_required="WORK",
                    description="Full work day")


# ---- 7. STUDY_BLOCK -------------------------------------------------------

def _create_study_block_episode(agent) -> Episode:
    """Focused study with periodic phone-distraction breaks."""
    duration = int(np.random.uniform(18, 36))   # 90-180 min
    study_apps = config.apps_in_categories("education", "productivity", "browser", "reading")
    break_apps = config.apps_in_categories("social", "short_video", "messaging")

    def study_tick(a, step, progress):
        a.energy = utils.clamp(a.energy - 0.4, max_val=100.0)
        a.boredom = utils.clamp(a.boredom + 0.4, max_val=100.0)

    steps = [
        EpisodeStep(name="focus_block", duration_ticks=duration, step_type="study",
                    on_tick=study_tick, generates_events=True,
                    apps_used=study_apps, state_effects={"energy": -10, "boredom": 8}),
        EpisodeStep(name="distraction_break", duration_ticks=4, step_type="break",
                    generates_events=True, apps_used=break_apps,
                    state_effects={"boredom": -10, "social_need": -5}),
    ]
    return _episode(agent, "STUDY_BLOCK", steps,
                    state_effects={"energy": -10, "boredom": 0},
                    priority=1.4, description="Study session")


# ---- 8. GO_TO_CAFE --------------------------------------------------------

def _create_go_to_cafe_episode(agent) -> Episode:
    cafes = agent.model.pois.get("CAFE", [])
    if not cafes:
        return _create_relax_at_home_episode(agent)
    cafe = random.choice([p for p in agent.leisure_pois if p.get("type") == "CAFE"] or cafes)

    travel = _make_travel_step(agent, cafe, name="travel_cafe",
                               apps=config.apps_in_categories("navigation", "music"))

    def eat_tick(a, step, progress):
        a.hunger = utils.clamp(a.hunger - 4, max_val=100.0)

    arrive = EpisodeStep(name="arrive_cafe", duration_ticks=1, step_type="arrive",
                         generates_events=True,
                         apps_used=config.apps_in_categories("photo", "social"))
    eat = EpisodeStep(name="eat_drink", duration_ticks=6, step_type="eat",
                      on_tick=eat_tick, generates_events=True,
                      apps_used=config.apps_in_categories("social", "messaging", "music"),
                      state_effects={"hunger": -25})
    chat = EpisodeStep(name="chat", duration_ticks=6, step_type="socialize",
                       generates_events=True,
                       apps_used=config.apps_in_categories("messaging", "social", "photo"),
                       state_effects={"social_need": -15, "boredom": -10})
    leave = EpisodeStep(name="leave_cafe", duration_ticks=1, step_type="leave",
                        generates_events=False, apps_used=[])

    return _episode(agent, "GO_TO_CAFE", [travel, arrive, eat, chat, leave],
                    state_effects={"hunger": -25, "social_need": -15, "boredom": -10, "energy": -8},
                    priority=1.0, location_required="CAFE",
                    description="Cafe outing")


# ---- 9. SOCIALIZE ---------------------------------------------------------

def _create_socialize_episode(agent) -> Episode:
    """Pick a leisure POI, hang out for a while."""
    candidates = [p for p in agent.leisure_pois if p.get("type") in ("CAFE", "PARK", "NIGHTLIFE")]
    if not candidates:
        candidates = list(agent.model.pois.get("CAFE", [])) + list(agent.model.pois.get("PARK", []))
    if not candidates:
        return _create_relax_at_home_episode(agent)
    spot = random.choice(candidates)

    travel = _make_travel_step(agent, spot, name="travel_social",
                               apps=config.apps_in_categories("navigation", "messaging", "music"))

    def social_tick(a, step, progress):
        a.social_need = utils.clamp(a.social_need - 1.5, max_val=100.0)
        a.boredom = utils.clamp(a.boredom - 1.0, max_val=100.0)

    duration = max(8, int(np.random.normal(18, 6)))   # 40-100 min
    hang = EpisodeStep(name="hang_out", duration_ticks=duration, step_type="socialize",
                       on_tick=social_tick, generates_events=True,
                       apps_used=config.apps_in_categories("messaging", "social", "photo"),
                       state_effects={"social_need": -25, "boredom": -15})
    leave = EpisodeStep(name="leave", duration_ticks=1, step_type="leave",
                        generates_events=False, apps_used=[])

    return _episode(agent, "SOCIALIZE", [travel, hang, leave],
                    state_effects={"social_need": -25, "boredom": -15, "energy": -8},
                    priority=1.0, description="Social hangout")


# ---- 10. EXERCISE --------------------------------------------------------

def _create_exercise_episode(agent) -> Episode:
    gym = agent.gym_poi
    if gym is None:
        # do an outdoor run from home
        gym = agent.home_poi

    travel = _make_travel_step(agent, gym, name="travel_gym",
                               apps=config.apps_in_categories("navigation", "music", "fitness"))

    def workout_tick(a, step, progress):
        a.energy = utils.clamp(a.energy - 1.6, max_val=100.0)
        a.hunger = utils.clamp(a.hunger + 0.6, max_val=100.0)

    warmup = EpisodeStep(name="warmup", duration_ticks=4, step_type="warmup",
                         on_tick=workout_tick, generates_events=True,
                         apps_used=config.apps_in_categories("fitness", "music"))
    workout = EpisodeStep(name="workout", duration_ticks=14, step_type="workout",
                          on_tick=workout_tick, generates_events=True,
                          apps_used=config.apps_in_categories("fitness", "music"),
                          state_effects={"energy": -25})
    cooldown = EpisodeStep(name="cooldown", duration_ticks=3, step_type="cooldown",
                           on_tick=workout_tick, generates_events=True,
                           apps_used=config.apps_in_categories("fitness", "music"))
    shower = EpisodeStep(name="shower", duration_ticks=3, step_type="shower",
                         generates_events=False, apps_used=[],
                         state_effects={"energy": 3})
    leave = EpisodeStep(name="leave", duration_ticks=1, step_type="leave",
                        generates_events=False, apps_used=[])

    return _episode(agent, "EXERCISE", [travel, warmup, workout, cooldown, shower, leave],
                    state_effects={"energy": -22, "boredom": -25, "hunger": 8},
                    priority=1.0, location_required="GYM",
                    description="Workout session")


# ---- 11. RELAX_AT_HOME ---------------------------------------------------

def _create_relax_at_home_episode(agent) -> Episode:
    duration = int(np.random.uniform(8, 22))

    def relax_tick(a, step, progress):
        a.energy = utils.clamp(a.energy + 0.6, max_val=100.0)
        a.boredom = utils.clamp(a.boredom - 0.5, max_val=100.0)

    apps = config.apps_in_categories("video", "short_video", "social",
                                     "music", "messaging", "reading")

    step = EpisodeStep(name="relax", duration_ticks=duration, step_type="relax",
                       on_tick=relax_tick, generates_events=True,
                       apps_used=apps, state_effects={"boredom": -5, "energy": 5})

    # ensure agent is at home
    def go_home(a, step):
        a.latitude = a.home_poi["latitude"]
        a.longitude = a.home_poi["longitude"]
        a.current_location = a.home_poi
    step.on_enter = go_home

    return _episode(agent, "RELAX_AT_HOME", [step],
                    state_effects={"energy": 12, "boredom": -10},
                    priority=0.8, location_required="HOME",
                    description="Home relaxation")


# ---- 12. CONTENT_BINGE ---------------------------------------------------

def _create_content_binge_episode(agent) -> Episode:
    """Long-form video / streaming session at home."""
    duration = int(np.random.uniform(20, 45))   # 100-225 min

    def binge_tick(a, step, progress):
        a.boredom = utils.clamp(a.boredom - 0.7, max_val=100.0)
        a.energy = utils.clamp(a.energy + 0.1, max_val=100.0)

    apps = config.apps_in_categories("streaming", "video", "short_video")

    step = EpisodeStep(name="binge", duration_ticks=duration, step_type="binge",
                       on_tick=binge_tick, generates_events=True,
                       apps_used=apps, state_effects={"boredom": -20})

    def go_home(a, step):
        a.latitude = a.home_poi["latitude"]
        a.longitude = a.home_poi["longitude"]
        a.current_location = a.home_poi
    step.on_enter = go_home

    return _episode(agent, "CONTENT_BINGE", [step],
                    state_effects={"boredom": -25},
                    priority=0.9, location_required="HOME",
                    description="Streaming/video binge")


# ---- 13. GAMING_MARATHON -------------------------------------------------

def _create_gaming_marathon_episode(agent) -> Episode:
    duration = int(np.random.uniform(20, 40))

    def gaming_tick(a, step, progress):
        a.energy = utils.clamp(a.energy - 0.9, max_val=100.0)
        a.boredom = utils.clamp(a.boredom - 0.8, max_val=100.0)
        a.hunger = utils.clamp(a.hunger + 0.4, max_val=100.0)

    apps = config.apps_in_categories("gaming", "messaging", "streaming")

    step = EpisodeStep(name="gaming", duration_ticks=duration, step_type="gaming",
                       on_tick=gaming_tick, generates_events=True,
                       apps_used=apps, state_effects={"boredom": -25})

    def go_home(a, step):
        a.latitude = a.home_poi["latitude"]
        a.longitude = a.home_poi["longitude"]
        a.current_location = a.home_poi
    step.on_enter = go_home

    return _episode(agent, "GAMING_MARATHON", [step],
                    state_effects={"boredom": -30, "energy": -20, "hunger": 15},
                    priority=1.0, location_required="HOME",
                    description="Gaming session")


# ---- 14. ERRAND_CHAIN ----------------------------------------------------

def _create_errand_chain_episode(agent) -> Episode:
    """Multi-stop trip across 2-3 commercial POIs."""
    pool = list(agent.model.pois.get("SHOPPING", [])) \
        + list(agent.model.pois.get("CAFE", []))[:5]
    if len(pool) < 2:
        return _create_relax_at_home_episode(agent)

    n_stops = random.choice([2, 2, 3])
    stops = random.sample(pool, k=min(n_stops, len(pool)))

    steps: List[EpisodeStep] = []
    for i, stop in enumerate(stops):
        steps.append(_make_travel_step(agent, stop, name=f"travel_stop_{i+1}",
                                       apps=config.apps_in_categories("navigation", "music"),
                                       energy_cost=-2))
        steps.append(EpisodeStep(
            name=f"stop_{i+1}_{stop.get('type','')}", duration_ticks=4, step_type="errand",
            generates_events=True,
            apps_used=config.apps_in_categories("shopping", "finance", "messaging"),
            state_effects={"energy": -3, "boredom": -2},
        ))
    # back home
    steps.append(_make_travel_step(agent, agent.home_poi, name="travel_home_after",
                                   apps=config.apps_in_categories("navigation", "music")))

    return _episode(agent, "ERRAND_CHAIN", steps,
                    state_effects={"energy": -15, "boredom": -10},
                    priority=0.9, description="Errands chain")


# ---- 15. EXPLORATION_DAY -------------------------------------------------

def _create_exploration_day_episode(agent) -> Episode:
    """Wander between landmarks/parks; long, photo-heavy, lots of GPS variety."""
    pool = list(agent.model.pois.get("LANDMARK", [])) \
        + list(agent.model.pois.get("PARK", [])) \
        + list(agent.model.pois.get("CAFE", []))[:8]
    if len(pool) < 2:
        return _create_socialize_episode(agent)

    n_stops = random.choice([3, 3, 4, 5])
    stops = random.sample(pool, k=min(n_stops, len(pool)))

    apps_explore = config.apps_in_categories("navigation", "photo", "social", "music")
    steps: List[EpisodeStep] = []
    for i, stop in enumerate(stops):
        steps.append(_make_travel_step(agent, stop, name=f"travel_explore_{i+1}",
                                       apps=apps_explore, energy_cost=-3))
        # linger
        linger_dur = int(np.random.uniform(6, 14))
        steps.append(EpisodeStep(
            name=f"explore_{i+1}_{stop.get('type','')}",
            duration_ticks=linger_dur, step_type="explore",
            generates_events=True, apps_used=apps_explore,
            state_effects={"boredom": -4, "energy": -3},
        ))
    steps.append(_make_travel_step(agent, agent.home_poi, name="travel_home_explore",
                                   apps=apps_explore, energy_cost=-3))

    return _episode(agent, "EXPLORATION_DAY", steps,
                    state_effects={"boredom": -30, "energy": -25, "social_need": -10},
                    priority=1.0, description="Wander/explore")


# ============================================================================
# 6. DISPATCHER
# ============================================================================

_FACTORIES = {
    "SLEEP":             _create_sleep_episode,
    "NIGHT_BROWSING":    _create_night_browsing_episode,
    "MORNING_ROUTINE":   _create_morning_routine_episode,
    "COMMUTE_TO_WORK":   _create_commute_to_work_episode,
    "COMMUTE_HOME":      _create_commute_home_episode,
    "WORK_DAY":          _create_work_day_episode,
    "STUDY_BLOCK":       _create_study_block_episode,
    "GO_TO_CAFE":        _create_go_to_cafe_episode,
    "SOCIALIZE":         _create_socialize_episode,
    "EXERCISE":          _create_exercise_episode,
    "RELAX_AT_HOME":     _create_relax_at_home_episode,
    "CONTENT_BINGE":     _create_content_binge_episode,
    "GAMING_MARATHON":   _create_gaming_marathon_episode,
    "ERRAND_CHAIN":      _create_errand_chain_episode,
    "EXPLORATION_DAY":   _create_exploration_day_episode,
}


def create_episode_instance(episode_type: str, agent) -> Optional[Episode]:
    factory = _FACTORIES.get(episode_type)
    if factory is None:
        logger.warning(f"Unknown episode type: {episode_type}")
        return None
    try:
        return factory(agent)
    except Exception as e:
        logger.error(f"Failed to create {episode_type}: {e}", exc_info=True)
        return None


# Install the per-day cache helper on SmartphoneUser at import time.
try:
    _install_helpers()
except Exception:
    # agent module may not be importable yet if circular; handled by fallback
    pass
