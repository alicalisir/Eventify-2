"""
Mesa Model — the world that contains agents, POIs, time, and the telemetry
recorder. Persona assignment is delegated to the personas module so this
file stays purely environmental.
"""

from __future__ import annotations

import logging
from datetime import datetime
from typing import Dict, List, Optional

import mesa

import config
import osm_integration
import utils
import personas
from planner import WeeklyPlanner

logger = logging.getLogger(__name__)


class SimulationEnvironment(mesa.Model):
    """Top-level Mesa model."""

    def __init__(
        self,
        num_agents: int = config.NUM_AGENTS,
        region: str = config.REGION,
        use_api: bool = False,
        start_datetime: Optional[datetime] = None,
        persona_distribution: Optional[Dict[str, float]] = None,
    ):
        super().__init__()
        self.num_agents = num_agents
        self.region = region
        self.persona_distribution = persona_distribution or personas.PERSONA_POPULATION_WEIGHTS

        # Time
        self.start_datetime = start_datetime or datetime(2024, 1, 1, 0, 0, 0)
        self.current_datetime = self.start_datetime
        self.current_tick = 0

        # POIs
        logger.info("Loading environment POIs...")
        self.pois: Dict[str, List[dict]] = osm_integration.load_environment(use_api=use_api)
        total = sum(len(v) for v in self.pois.values())
        logger.info(f"Loaded {total} POIs across {len(self.pois)} categories")
        if total == 0:
            raise ValueError("No POIs loaded — check region or API")

        # Scheduler
        self.schedule = mesa.time.RandomActivation(self)

        # Telemetry buffers
        self.gps_pings: List[dict] = []
        self.app_sessions: List[dict] = []
        self.screen_events: List[dict] = []
        self.episode_log: List[dict] = []

        # Hierarchical planner (Level 2). Swap in LLMPlannerStub subclass to
        # plug in an LLM-driven theme picker.
        self.planner = WeeklyPlanner()

    # ------------------------------------------------------- agent factory
    def create_agents(self, agent_class):
        """Create N agents with persona-conditioned profiles."""
        import random
        ids = list(self.persona_distribution.keys())
        weights = list(self.persona_distribution.values())

        for i in range(self.num_agents):
            persona_id = random.choices(ids, weights=weights, k=1)[0]
            agent = agent_class(unique_id=i, model=self, persona_id=persona_id)
            self.schedule.add(agent)

        logger.info(f"Created {self.num_agents} agents")
        # Persona breakdown
        from collections import Counter
        breakdown = Counter(a.persona_id for a in self.schedule.agents)
        for pid, n in sorted(breakdown.items(), key=lambda x: -x[1]):
            logger.info(f"  {pid:18s}: {n}")

    # ------------------------------------------------------------- ticking
    def step(self):
        self.schedule.step()
        self.current_tick += 1
        self.current_datetime = utils.tick_to_datetime(self.current_tick, self.start_datetime)

        if self.current_tick % config.TICKS_PER_DAY == 0:
            day = self.current_tick // config.TICKS_PER_DAY
            logger.info(
                f"Day {day}/{config.SIMULATION_DAYS}  "
                f"gps={len(self.gps_pings):,}  apps={len(self.app_sessions):,}  "
                f"episodes={len(self.episode_log):,}"
            )

    def run_simulation(self, total_ticks: Optional[int] = None):
        total = total_ticks or config.TOTAL_TICKS
        logger.info(f"Running simulation for {total} ticks ...")
        for _ in range(total):
            self.step()
        logger.info("Simulation complete.")

    # ----------------------------------------------------- time helpers
    def get_current_hour(self) -> int:
        return self.current_datetime.hour

    def is_weekend(self) -> bool:
        return self.current_datetime.weekday() >= 5

    # ----------------------------------------------------- recorders
    def add_gps_ping(
        self,
        user_id: int,
        lat: float,
        lon: float,
        accuracy_m: float = 10.0,
        speed_mps: float = 0.0,
        dwell_time_s: float = 0.0,
        movement_state: str = "stationary",
        gps_mode: str = "normal",
    ):
        self.gps_pings.append({
            "user_id": user_id,
            "timestamp": self.current_datetime.isoformat(),
            "latitude": round(lat, 6),
            "longitude": round(lon, 6),
            "accuracy": round(accuracy_m, 1),
            "speed_mps": round(speed_mps, 2),
            "dwell_time_s": int(dwell_time_s),
            "movement_state": movement_state,
            "gps_mode": gps_mode,
        })

    def add_app_session(
        self,
        user_id: int,
        app: str,
        category: str,
        duration_min: float,
        foreground: bool = True,
    ):
        self.app_sessions.append({
            "user_id": user_id,
            "timestamp": self.current_datetime.isoformat(),
            "app": app,
            "category": category,
            "duration_min": round(duration_min, 2),
            "state": "foreground" if foreground else "background",
        })

    def add_screen_event(self, user_id: int, event_type: str, app: str = ""):
        """event_type: on, off, unlock, lock, notification."""
        self.screen_events.append({
            "user_id": user_id,
            "timestamp": self.current_datetime.isoformat(),
            "event_type": event_type,
            "app": app,
        })

    def add_episode_log(self, entry: dict):
        # add a timestamp at logging time
        e = dict(entry)
        e.setdefault("timestamp", self.current_datetime.isoformat())
        self.episode_log.append(e)
