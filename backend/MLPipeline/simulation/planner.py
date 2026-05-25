"""
Hierarchical Planner (Level 2)
==============================

Adds a **daily-theme** layer on top of the per-tick episode utility selection.
The episode FSM (Level 1) is good at minute-to-minute decisions but blind to
the bigger picture: a real person tends to *commit* to a kind of day —
"focused work day", "lazy Sunday", "errands day", "social night out" —
and that commitment biases hour-by-hour episode choices.

The planner runs once per simulated day (or whenever asked) and produces a
DailyPlan: a small theme tag plus a multiplier table that the EpisodeManager
applies on top of its base utility scores. This gives:

  utility_final(episode) = utility_base(episode) * theme_multiplier(episode)

Plug-in interface:
  - WeeklyPlanner (default)  — rule + persona-conditioned sampling
  - LLMPlannerStub           — placeholder; subclass and override .pick_theme()
                               with a real LLM call if desired.
"""

from __future__ import annotations

import random
from dataclasses import dataclass, field
from typing import Dict, List, Optional


# ============================================================================
# 1. DAILY THEMES
# ============================================================================
#
# Each theme is a multiplier vector on episode utilities. 1.0 = neutral.
# Values >1 boost; <1 suppress; 0 effectively forbids.

DAILY_THEMES: Dict[str, Dict[str, float]] = {
    "FOCUSED_WORK": {
        "WORK_DAY": 1.5, "STUDY_BLOCK": 1.4, "COMMUTE_TO_WORK": 1.4,
        "COMMUTE_HOME": 1.4, "MORNING_ROUTINE": 1.3,
        "GAMING_MARATHON": 0.4, "CONTENT_BINGE": 0.6, "EXPLORATION_DAY": 0.3,
        "ERRAND_CHAIN": 0.6, "SOCIALIZE": 0.7,
    },
    "LAZY_DAY": {
        "WORK_DAY": 0.0, "STUDY_BLOCK": 0.4, "COMMUTE_TO_WORK": 0.0,
        "COMMUTE_HOME": 0.0,
        "RELAX_AT_HOME": 1.6, "CONTENT_BINGE": 1.7, "GAMING_MARATHON": 1.4,
        "NIGHT_BROWSING": 1.3, "SLEEP": 1.2, "EXERCISE": 0.5,
    },
    "SOCIAL_NIGHT": {
        "SOCIALIZE": 1.8, "GO_TO_CAFE": 1.5, "EXPLORATION_DAY": 1.2,
        "RELAX_AT_HOME": 0.6, "CONTENT_BINGE": 0.5, "STUDY_BLOCK": 0.6,
    },
    "ERRANDS_DAY": {
        "ERRAND_CHAIN": 2.0, "GO_TO_CAFE": 1.3, "EXERCISE": 0.8,
        "WORK_DAY": 0.2, "STUDY_BLOCK": 0.4,
    },
    "FITNESS_DAY": {
        "EXERCISE": 1.8, "MORNING_ROUTINE": 1.2,
        "GAMING_MARATHON": 0.4, "NIGHT_BROWSING": 0.5,
        "CONTENT_BINGE": 0.7,
    },
    "EXPLORATION": {
        "EXPLORATION_DAY": 2.0, "GO_TO_CAFE": 1.3, "SOCIALIZE": 1.2,
        "WORK_DAY": 0.0, "STUDY_BLOCK": 0.0, "RELAX_AT_HOME": 0.6,
    },
    "ROUTINE": {},  # neutral — uses base utilities only
    "CHAOTIC": {
        # Kriz/Düzensiz default: amplify variance by boosting random episodes
        # selected at sample time (handled in WeeklyPlanner)
    },
}


# ============================================================================
# 2. DAILY PLAN
# ============================================================================

@dataclass
class DailyPlan:
    """A plan for one simulated day."""
    date: str
    theme: str
    multipliers: Dict[str, float] = field(default_factory=dict)
    notes: str = ""

    def multiplier_for(self, episode_name: str) -> float:
        return self.multipliers.get(episode_name, 1.0)


# ============================================================================
# 3. PLANNER INTERFACE
# ============================================================================

class Planner:
    """Base interface — subclass and override pick_theme()."""

    def plan_day(self, agent, weekday: int) -> DailyPlan:
        theme = self.pick_theme(agent, weekday)
        multipliers = dict(DAILY_THEMES.get(theme, {}))
        if theme == "CHAOTIC":
            multipliers = self._chaotic_multipliers()
        return DailyPlan(
            date=str(agent.model.current_datetime.date()),
            theme=theme,
            multipliers=multipliers,
            notes=f"weekday={weekday}",
        )

    def pick_theme(self, agent, weekday: int) -> str:
        raise NotImplementedError

    @staticmethod
    def _chaotic_multipliers() -> Dict[str, float]:
        # randomly amplify 2-3 episode types for chaotic days
        all_eps = ["WORK_DAY", "STUDY_BLOCK", "GO_TO_CAFE", "SOCIALIZE",
                   "EXERCISE", "GAMING_MARATHON", "CONTENT_BINGE",
                   "EXPLORATION_DAY", "ERRAND_CHAIN", "NIGHT_BROWSING"]
        chosen = random.sample(all_eps, k=random.choice([2, 3]))
        m = {}
        for ep in chosen:
            m[ep] = random.choice([1.5, 1.7, 2.0])
        # randomly suppress 1-2 too
        suppress = random.sample([e for e in all_eps if e not in chosen], k=2)
        for ep in suppress:
            m[ep] = random.choice([0.3, 0.5])
        return m


# ============================================================================
# 4. WEEKLY PLANNER  (rule + persona-conditioned sampling)
# ============================================================================

class WeeklyPlanner(Planner):
    """
    Default planner. Persona-conditioned distributions over daily themes.
    Probabilities are softened on weekends and biased by latent traits.
    """

    # base persona → theme distribution (weekday)
    _WEEKDAY_DIST = {
        "PROFESYONEL":     {"FOCUSED_WORK": 0.7, "ROUTINE": 0.2, "FITNESS_DAY": 0.05, "ERRANDS_DAY": 0.05},
        "ERKENCI":         {"FOCUSED_WORK": 0.55, "FITNESS_DAY": 0.2, "ROUTINE": 0.2, "ERRANDS_DAY": 0.05},
        "OGRENCI":         {"FOCUSED_WORK": 0.6, "ROUTINE": 0.2, "SOCIAL_NIGHT": 0.15, "LAZY_DAY": 0.05},
        "SPORCU":          {"FITNESS_DAY": 0.5, "FOCUSED_WORK": 0.3, "ROUTINE": 0.15, "EXPLORATION": 0.05},
        "GECE_KUSU":       {"LAZY_DAY": 0.35, "ROUTINE": 0.3, "SOCIAL_NIGHT": 0.2, "FOCUSED_WORK": 0.15},
        "OYUNCU":          {"LAZY_DAY": 0.5, "ROUTINE": 0.25, "FOCUSED_WORK": 0.15, "SOCIAL_NIGHT": 0.1},
        "ICERIK_TUKETICI": {"LAZY_DAY": 0.4, "ROUTINE": 0.35, "FOCUSED_WORK": 0.2, "ERRANDS_DAY": 0.05},
        "EVCIMEN":         {"LAZY_DAY": 0.45, "ROUTINE": 0.4, "ERRANDS_DAY": 0.1, "FOCUSED_WORK": 0.05},
        "SOSYAL":          {"SOCIAL_NIGHT": 0.4, "ROUTINE": 0.25, "FOCUSED_WORK": 0.2, "EXPLORATION": 0.15},
        "SEYYAH":          {"EXPLORATION": 0.55, "ROUTINE": 0.2, "FOCUSED_WORK": 0.15, "ERRANDS_DAY": 0.1},
        "KRIZ_DUZENSIZ":   {"CHAOTIC": 0.55, "LAZY_DAY": 0.2, "ROUTINE": 0.15, "SOCIAL_NIGHT": 0.1},
        "HIBRIT":          {"ROUTINE": 0.3, "FOCUSED_WORK": 0.25, "LAZY_DAY": 0.2, "SOCIAL_NIGHT": 0.15, "FITNESS_DAY": 0.1},
    }

    # weekend overrides — most personas relax more
    _WEEKEND_DIST = {
        "PROFESYONEL":     {"LAZY_DAY": 0.35, "ERRANDS_DAY": 0.2, "SOCIAL_NIGHT": 0.2, "FITNESS_DAY": 0.15, "EXPLORATION": 0.1},
        "ERKENCI":         {"FITNESS_DAY": 0.35, "ERRANDS_DAY": 0.25, "EXPLORATION": 0.2, "ROUTINE": 0.2},
        "OGRENCI":         {"SOCIAL_NIGHT": 0.4, "LAZY_DAY": 0.3, "FOCUSED_WORK": 0.2, "EXPLORATION": 0.1},
        "SPORCU":          {"FITNESS_DAY": 0.55, "EXPLORATION": 0.2, "SOCIAL_NIGHT": 0.15, "ROUTINE": 0.1},
        "GECE_KUSU":       {"LAZY_DAY": 0.5, "SOCIAL_NIGHT": 0.3, "ROUTINE": 0.2},
        "OYUNCU":          {"LAZY_DAY": 0.65, "SOCIAL_NIGHT": 0.2, "ROUTINE": 0.15},
        "ICERIK_TUKETICI": {"LAZY_DAY": 0.6, "ROUTINE": 0.25, "ERRANDS_DAY": 0.15},
        "EVCIMEN":         {"LAZY_DAY": 0.6, "ROUTINE": 0.3, "ERRANDS_DAY": 0.1},
        "SOSYAL":          {"SOCIAL_NIGHT": 0.55, "EXPLORATION": 0.2, "LAZY_DAY": 0.15, "ERRANDS_DAY": 0.1},
        "SEYYAH":          {"EXPLORATION": 0.7, "SOCIAL_NIGHT": 0.2, "ROUTINE": 0.1},
        "KRIZ_DUZENSIZ":   {"CHAOTIC": 0.6, "LAZY_DAY": 0.25, "SOCIAL_NIGHT": 0.15},
        "HIBRIT":          {"LAZY_DAY": 0.3, "SOCIAL_NIGHT": 0.25, "EXPLORATION": 0.2, "ERRANDS_DAY": 0.15, "FITNESS_DAY": 0.1},
    }

    def pick_theme(self, agent, weekday: int) -> str:
        is_weekend = weekday >= 5
        dist = (self._WEEKEND_DIST if is_weekend else self._WEEKDAY_DIST).get(
            agent.persona_id, {"ROUTINE": 1.0}
        )

        # latent trait nudge: very stable agents lean more towards ROUTINE
        dist = dict(dist)
        if agent.profile.routine_stability > 0.7 and "ROUTINE" in dist:
            dist["ROUTINE"] = dist["ROUTINE"] + 0.15
        if agent.profile.routine_stability < 0.3 and "CHAOTIC" in dist:
            dist["CHAOTIC"] = dist.get("CHAOTIC", 0) + 0.15

        # normalize
        total = sum(dist.values())
        keys = list(dist.keys())
        weights = [v / total for v in dist.values()]
        return random.choices(keys, weights=weights, k=1)[0]


# ============================================================================
# 5. LLM PLANNER STUB  (Level 2 advanced — interface only)
# ============================================================================

class LLMPlannerStub(Planner):
    """
    Placeholder for an LLM-driven planner. To use:
      class MyLLMPlanner(LLMPlannerStub):
          def pick_theme(self, agent, weekday):
              prompt = self._build_prompt(agent, weekday)
              response = call_llm(prompt)
              return self._parse_theme(response)

    The LLM receives:
      - agent.persona_id and key latent traits
      - the last 3 days of episode history
      - weekday + recent state (energy, social_need, ...)
    and must reply with one of the theme keys in DAILY_THEMES.

    Falls back to ROUTINE if not subclassed.
    """

    def pick_theme(self, agent, weekday: int) -> str:
        return "ROUTINE"

    def _build_prompt(self, agent, weekday: int) -> str:
        recent = agent.episode_history[-10:]
        return (
            f"Persona: {agent.persona_id}\n"
            f"Latent traits: chronotype={agent.profile.chronotype:.2f}, "
            f"work_intensity={agent.profile.work_intensity:.2f}, "
            f"social_need={agent.profile.social_need:.2f}\n"
            f"Weekday: {weekday}\n"
            f"Recent episodes: {[e['episode_name'] for e in recent]}\n"
            f"Pick one daily theme from: {list(DAILY_THEMES.keys())}\n"
        )
