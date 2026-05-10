"""
Behavior System - Utility-Based Decision Making
Calculate action utilities and select actions stochastically
"""

import numpy as np
import random
import config
import utils
from typing import Dict


class BehaviorSystem:
    """
    Utility-based behavior system for agents.

    Calculates utility (desirability) for each possible action based on:
    - Time of day (schedule)
    - Agent internal state (energy, boredom, hunger, social_need)
    - Current location
    - Persona preferences

    Selects action via softmax (probability proportional to utility).
    """

    ACTIONS = [
        "stay_idle",
        "commute_to_work",
        "work",
        "commute_home",
        "relax_at_home",
        "go_to_cafe",
        "socialize",
        "exercise",
        "sleep",
    ]

    def __init__(self, agent):
        """
        Args:
            agent: Reference to SmartphoneUser agent
        """
        self.agent = agent
        self.model = agent.model

    def decide_action(self) -> str:
        """
        Evaluate all actions and select best one via softmax.

        Returns:
            Selected action name
        """
        # Calculate utility for each action
        utilities = {}
        for action in self.ACTIONS:
            utilities[action] = self.calculate_action_utility(action)

        # Softmax selection (probabilistic, with stochastic tie-breaking)
        action = utils.softmax(utilities, temperature=1.5)
        return action

    def calculate_action_utility(self, action: str) -> float:
        """
        Calculate utility (desirability) for an action.

        Utility factors:
        - Schedule compatibility (0-50 points)
        - Energy availability (0-50 points)
        - Boredom relief (0-30 points)
        - Social interaction (0-20 points)
        - Hunger satisfaction (0-20 points)
        - Persona preferences (0-30 points)

        Args:
            action: Action name

        Returns:
            Utility score (non-negative float)
        """
        utility = 0.0

        time_of_day = self.model.get_time_of_day()
        hour = self.model.get_current_hour()
        is_weekend = self.model.is_weekend()

        # ===== 1. SCHEDULE COMPATIBILITY =====
        # High utility for activities aligned with time of day

        if action == "sleep":
            # Sleep during night hours
            if hour >= self.agent.persona.sleep_start_hour or hour < self.agent.persona.sleep_end_hour:
                utility += 50
            else:
                utility += -30
            # Energy plays huge role
            if self.agent.energy < config.ENERGY_THRESHOLD_SLEEP:
                utility += 50

        elif action == "commute_to_work":
            # Commute in morning (7-9 AM)
            if 7 <= hour < 9:
                utility += 40
            elif self.agent.persona.schedule_regular:
                utility += 20
            else:
                utility += -10

        elif action == "work":
            # Work during work hours
            if self.agent.persona.work_start_hour <= hour < self.agent.persona.work_end_hour:
                utility += 50
            elif is_weekend:
                utility += -40
            else:
                utility += -20

        elif action == "commute_home":
            # Commute in evening (5-7 PM)
            if 17 <= hour < 19:
                utility += 40
            else:
                utility += -10

        elif action == "relax_at_home":
            # Relax in evening/night
            if hour >= 19 or hour < 7:
                utility += 30
            elif is_weekend:
                utility += 20

        elif action in ["go_to_cafe", "socialize"]:
            # Social activities in afternoon/evening
            if 14 <= hour <= 22:
                utility += 30
            else:
                utility += -10

        elif action == "exercise":
            # Exercise in morning or evening
            if (6 <= hour <= 8) or (17 <= hour <= 20):
                utility += 25
            if self.agent.persona.exercise_enthusiast:
                utility += 30

        elif action == "stay_idle":
            # Idle when nothing else is good
            utility += 10

        # ===== 2. ENERGY AVAILABILITY =====
        # Energy is critical for activities

        energy_ratio = self.agent.energy / 100.0

        if action in ["work", "exercise", "commute_to_work", "commute_home"]:
            # High-energy activities need energy
            if energy_ratio > 0.6:
                utility += 30
            elif energy_ratio > 0.4:
                utility += 10
            else:
                utility += -40

        elif action == "relax_at_home":
            # Low energy → need rest
            if energy_ratio < 0.4:
                utility += 40
            elif energy_ratio < 0.6:
                utility += 20

        # ===== 3. BOREDOM RELIEF =====
        # Seek interesting activities when bored

        boredom_ratio = self.agent.boredom / 100.0

        if boredom_ratio > config.BOREDOM_THRESHOLD_SEEK_ACTIVITY / 100:
            # Very bored → seek engaging activities
            if action in ["go_to_cafe", "socialize", "relax_at_home"]:
                utility += 30
            elif action == "stay_idle":
                utility += -50

        # ===== 4. SOCIAL NEED =====
        # Seek socializing when lonely

        social_ratio = self.agent.social_need / 100.0

        if self.agent.persona.social_active:
            social_threshold = 0.5  # Lower threshold for social agents
        else:
            social_threshold = 0.7  # Higher threshold for introverts

        if social_ratio > social_threshold:
            # Lonely → seek social activities
            if action in ["go_to_cafe", "socialize"]:
                utility += 40
            elif action == "stay_idle":
                utility += -30

        # ===== 5. HUNGER =====
        # Seek food when hungry

        hunger_ratio = self.agent.hunger / 100.0

        if hunger_ratio > config.HUNGER_THRESHOLD_EAT / 100:
            # Hungry → go to cafe/restaurant
            if action in ["go_to_cafe"]:
                utility += 40
            elif action in ["relax_at_home", "work", "exercise"]:
                utility += -20

        # ===== 6. PERSONA PREFERENCES =====
        # Apply personality modifiers

        if action == "work":
            if self.agent.persona.work_focused:
                utility += 30
            else:
                utility += -20

        if action in ["go_to_cafe", "socialize"]:
            if self.agent.persona.social_active:
                utility += 25
            else:
                utility += -10

        if action == "relax_at_home":
            if self.agent.persona.media_consumer:
                utility += 20

        if action == "exercise":
            if self.agent.persona.exercise_enthusiast:
                utility += 25
            else:
                utility += -5

        # ===== 7. LOCATION CONSTRAINTS =====
        # Some actions only make sense in certain locations

        if action == "work" and self.agent.current_location != self.agent.work_poi:
            # Can't work away from work location
            utility += -50

        if action == "relax_at_home" and self.agent.current_location != self.agent.home_poi:
            # Can't relax at home if not at home
            utility += -30

        if action == "exercise" and self.agent.current_location not in self.agent.leisure_pois:
            # Can't exercise away from gym
            utility += -30

        # ===== ENSURE NON-NEGATIVITY =====
        utility = max(0.0, utility)

        return utility
