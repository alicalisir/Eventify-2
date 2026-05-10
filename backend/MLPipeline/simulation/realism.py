"""
Realism upgrade pack A — sim-to-real calibration.

Three calibration layers applied on top of the existing architecture:
  1. AppSessionSampler      — per-category lognormal durations + micro-burst loops
  2. GPSQualityModel        — signal dropout windows, variable accuracy, indoor/transit modes
  3. DeviceImperfectionModel — permission-off windows, offline periods, battery-critical truncation

None of these change the FSM, planner, or persona pipeline — they only affect
what telemetry is *recorded* (or withheld) after the behavioral decision is made.
"""

from __future__ import annotations

import math
import random
from typing import Tuple


# ============================================================================
# 1. APP SESSION DURATIONS — lognormal distributions + micro-burst behavior
# ============================================================================
#
# Replaces flat uniform(lo, hi) * scale with per-category lognormal sampling.
# Real-world session duration distributions are right-skewed (most sessions short,
# occasional very long binge sessions). Lognormal captures this shape naturally.
#
# Parameters (mu_log, sigma_log) tuned to match published digital behavior data:
#   - Short-form video (TikTok): median ~33 min, fat tail to 8h binge
#   - Messaging: median ~5 min (quick reply cycle)
#   - Streaming: median ~55 min (one episode unit)

LOGNORMAL_SESSION_PARAMS: dict[str, tuple[float, float]] = {
    # category           (mu,   sigma)   median = exp(mu), sigma drives tail fatness
    "short_video":      (3.50,  1.05),  # TikTok/Reels   — median 33 min
    "social":           (2.80,  0.95),  # Instagram/Twitter — median 16 min
    "streaming":        (4.00,  0.75),  # Netflix/Disney+  — median 55 min
    "video":            (3.40,  0.90),  # YouTube          — median 30 min
    "gaming":           (3.50,  1.00),  # mobile games     — median 33 min
    "messaging":        (1.60,  0.85),  # WhatsApp/Telegram — median 5 min
    "productivity":     (2.10,  0.75),  # mail/office      — median 8 min
    "music":            (3.60,  0.55),  # Spotify (background) — median 37 min
    "browser":          (2.30,  0.85),  # Chrome           — median 10 min
    "navigation":       (2.20,  0.70),  # Maps             — median 9 min
    "fitness":          (3.80,  0.50),  # Strava           — median 45 min (workout)
    "education":        (3.20,  0.70),  # Duolingo/Coursera — median 25 min
    "reading":          (3.10,  0.70),  # Kindle/Medium    — median 22 min
    "news":             (2.20,  0.70),  # news apps        — median 9 min
    "shopping":         (2.40,  0.85),  # Trendyol/Getir   — median 11 min
    "finance":          (1.40,  0.60),  # banking          — median 4 min
    "photo":            (1.40,  0.65),  # camera/gallery   — median 4 min
    "ride_share":       (1.60,  0.60),  # Uber/Bitaksi     — median 5 min
    "dating":           (2.50,  0.90),  # Tinder           — median 12 min
}

# Hard caps per category to prevent outlier sessions that break daily plausibility.
SESSION_MAX_MIN: dict[str, float] = {
    "short_video":  480.0,  # 8 h TikTok binge is the extreme
    "streaming":    360.0,
    "gaming":       360.0,
    "video":        300.0,
    "social":       180.0,
    "music":        360.0,   # background music runs all day
    "messaging":     60.0,
    "productivity":  90.0,
    "browser":      180.0,
    "fitness":      180.0,
    "education":    120.0,
    "reading":      180.0,
}
_DEFAULT_MAX_MIN = 120.0


class AppSessionSampler:
    """
    Lognormal session-duration sampler + micro-burst emission logic.

    Usage:
        duration = AppSessionSampler.sample_duration("social", scale=1.1)
        if random.random() < AppSessionSampler.micro_burst_prob(0.8):
            micro_dur = AppSessionSampler.sample_micro_session()
    """

    @staticmethod
    def sample_duration(category: str, screen_time_scale: float) -> float:
        """
        Draw a session duration from a category-conditioned lognormal.

        screen_time_scale: persona multiplier from screen_time_target_h (~0.4..1.8).
            Applied as a log-space shift so it stretches the full distribution
            rather than only rescaling the mean.
        """
        mu, sigma = LOGNORMAL_SESSION_PARAMS.get(category, (2.50, 0.85))
        # shift mu in log-space by persona scale factor
        mu_adj = mu + math.log(max(0.1, screen_time_scale))
        raw = math.exp(mu_adj + sigma * random.gauss(0, 1))
        cap = SESSION_MAX_MIN.get(category, _DEFAULT_MAX_MIN)
        return max(0.5, min(raw, cap))

    @staticmethod
    def micro_burst_prob(digital_addiction: float) -> float:
        """Per-tick probability of a micro-burst unlock-check-dismiss loop."""
        # Range: 5% (low addiction) to 25% (high addiction)
        return 0.05 + 0.20 * digital_addiction

    @staticmethod
    def sample_micro_session() -> float:
        """
        Duration (minutes) for a single micro-burst session (quick glance).
        Exponential distribution: mean ~0.7 min, capped at 2.5 min.
        """
        return min(2.5, max(0.3, random.expovariate(1.0 / 0.7)))


# ============================================================================
# 2. GPS QUALITY MODEL — dropout windows + variable accuracy
# ============================================================================

class GPSQualityModel:
    """
    Per-agent GPS signal-quality state machine.

    Modes (slow-changing, persist across ticks):
      "normal"        — clear-sky outdoors, 5-15m accuracy
      "indoor"        — weak indoor signal, 20-60m; occasional 1-3 tick dropouts
      "battery_saver" — OS switched to cell-tower location, 50-250m, coarser sampling
      "dropout"       — no GPS fix; ping suppressed until recovery

    Integration:
        Call tick() once per agent step *after* episode FSM runs (so in_transit is current).
        Then gate telemetry using should_emit_ping(), and get noise from effective_noise_m().
    """

    def __init__(self):
        self.mode: str = "normal"
        self._dropout_end: int = 0   # tick when "dropout" mode ends
        self._mode_end: int = 0      # tick when "indoor"/"battery_saver" ends

    def tick(self, tick: int, agent) -> None:
        """Stochastic mode transitions — called once per simulation tick."""

        # --- recover from brief total dropout ---
        if self.mode == "dropout":
            if tick >= self._dropout_end:
                self.mode = "normal"
            return  # no further transitions while blacked out

        # --- battery_saver persists while energy low ---
        if self.mode == "battery_saver":
            if agent.energy > 40.0 or tick >= self._mode_end:
                self.mode = "normal"
            return

        # --- indoor mode: leave when agent starts moving ---
        if self.mode == "indoor":
            if agent.in_transit or tick >= self._mode_end:
                self.mode = "normal"
            elif random.random() < 0.07:  # 7%/tick: brief total blackout inside building
                self.mode = "dropout"
                self._dropout_end = tick + random.randint(1, 3)
            return

        # --- from normal: check all transition triggers ---
        # Low battery → battery saver mode
        if agent.energy < 22.0 and random.random() < 0.03:
            self.mode = "battery_saver"
            self._mode_end = tick + random.randint(6, 48)  # 30 min – 4 h
            return

        # Stationary at a fixed location (home/work) → indoor signal degradation
        at_fixed = (agent.current_location is getattr(agent, "home_poi", None) or
                    agent.current_location is getattr(agent, "work_poi", None))
        if not agent.in_transit and at_fixed and random.random() < 0.012:
            self.mode = "indoor"
            self._mode_end = tick + random.randint(6, 36)  # 30 min – 3 h
            return

        # In transit → occasional tunnel / underpass dropout
        if agent.in_transit and random.random() < 0.035:
            self.mode = "dropout"
            self._dropout_end = tick + random.randint(1, 3)  # 5-15 min

    def should_emit_ping(self, tick: int, gps_every: int) -> bool:
        """
        True if a GPS ping record should be emitted this tick.

        gps_every: ticks between ping attempts (= GPS_SAMPLING_INTERVAL / TICK_DURATION)
        """
        if self.mode == "dropout":
            return False
        if self.mode == "battery_saver":
            # Coarser polling: every ~30 min (3× normal interval)
            return tick % (gps_every * 3) == 0
        if self.mode == "indoor":
            return random.random() > 0.20  # skip ~20% of indoor pings
        return True

    def effective_noise_m(self, in_transit: bool) -> float:
        """
        Noise standard deviation (meters) to pass to utils.add_gps_noise().
        Varies by mode and movement state.
        """
        if self.mode == "indoor":
            return random.uniform(18.0, 55.0)
        if self.mode == "battery_saver":
            return random.uniform(50.0, 200.0)
        # Normal outdoor: slightly higher noise while moving
        if in_transit:
            return random.uniform(8.0, 20.0)
        return random.uniform(3.0, 10.0)

    def reported_accuracy_m(self, noise_m: float) -> float:
        """
        Reported accuracy value for the CSV (what the device OS reports to apps).
        Device typically claims somewhat better accuracy than actual noise floor.
        """
        if self.mode == "battery_saver":
            return round(random.uniform(50.0, 250.0), 1)
        if self.mode == "indoor":
            return round(random.uniform(15.0, 50.0), 1)
        return round(noise_m * random.uniform(0.9, 1.6), 1)


# ============================================================================
# 3. DEVICE IMPERFECTION MODEL — permission windows, offline, battery-critical
# ============================================================================

class DeviceImperfectionModel:
    """
    Per-agent device-level outage tracker.

    Three independent overlapping outage types:
      permission_off   — user toggled location/app-tracking permission off
                         → no GPS pings OR app-session records
      offline          — airplane mode, dead battery, device restart
                         → no telemetry at all (GPS + app + screen all suppressed)
      battery_critical — OS aggressive power-saving kills background processes
                         → sessions may be truncated mid-record

    Each activates stochastically each tick with realistic frequencies:
      permission_off  ~once per 17 h on average (0.06%/tick), lasts 2–10 h
      offline         ~once per 35 h (0.03%/tick),            lasts 30 min – 2.5 h
      battery_critical triggered by energy proxy < 15%,       lasts 15 min – 1 h

    These model real measurement gaps seen in passive telemetry datasets.
    """

    def __init__(self):
        self._perm_off_end: int = -1   # permission-off window end tick (-1 = inactive)
        self._offline_end: int = -1    # offline window end tick
        self._batt_crit_end: int = -1  # battery-critical window end tick

    def tick(self, tick: int, agent) -> None:
        """Evaluate outage activations each simulation tick."""
        # Permission toggle — rare, user-initiated
        if tick > self._perm_off_end and random.random() < 0.0006:
            self._perm_off_end = tick + random.randint(24, 120)  # 2–10 h

        # Device offline (airplane mode, crash, dead battery)
        if tick > self._offline_end and random.random() < 0.0003:
            self._offline_end = tick + random.randint(6, 30)     # 30 min – 2.5 h

        # Battery critical — proxy: use agent energy state as battery proxy
        if tick > self._batt_crit_end and agent.energy < 15.0:
            self._batt_crit_end = tick + random.randint(3, 12)   # 15 min – 1 h

    # -- gate methods --------------------------------------------------------

    def permission_off(self, tick: int) -> bool:
        return tick <= self._perm_off_end

    def is_offline(self, tick: int) -> bool:
        return tick <= self._offline_end

    def battery_critical(self, tick: int) -> bool:
        return tick <= self._batt_crit_end

    def can_record_gps(self, tick: int) -> bool:
        """GPS telemetry recordable (not blocked by permission or offline)."""
        return not self.permission_off(tick) and not self.is_offline(tick)

    def can_record_app(self, tick: int) -> bool:
        """App-session recordable (not blocked by permission or offline)."""
        return not self.permission_off(tick) and not self.is_offline(tick)

    def can_record_screen(self, tick: int) -> bool:
        """Screen events recordable (blocked only when fully offline)."""
        return not self.is_offline(tick)

    def truncate_session(self, duration_min: float, tick: int) -> float:
        """
        Possibly truncate a session to simulate background-process kills.

        Two sources of truncation:
          - Battery critical: 18% chance per session, trims to 10–40%
          - Baseline OS kill:  1.5% chance any time, trims to 15–50%
        """
        if self.battery_critical(tick) and random.random() < 0.18:
            return duration_min * random.uniform(0.10, 0.40)
        if random.random() < 0.015:
            return duration_min * random.uniform(0.15, 0.50)
        return duration_min
