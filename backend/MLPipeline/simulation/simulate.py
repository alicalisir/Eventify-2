"""
Persona-Conditioned Synthetic Population & Smartphone Telemetry Simulator
=========================================================================

CLI:
    python simulate.py                  # default 100 agents, 7 days
    python simulate.py --agents 30 --days 3
    python simulate.py --use-api        # fetch real Istanbul POIs from Overpass

Outputs land in FakeData/out/:
    user_profile.csv   users.csv
    gps_pings.csv      app_sessions.csv   screen_events.csv
    episode_log.csv    daily_summary.csv
"""

from __future__ import annotations

import argparse
import logging
import random
import sys
from datetime import datetime

import numpy as np

import config
import data_export
from agent import SmartphoneUser
from environment import SimulationEnvironment

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
)
logger = logging.getLogger("simulate")


def parse_args(argv=None):
    p = argparse.ArgumentParser(description="Persona-conditioned smartphone telemetry simulator")
    p.add_argument("--agents", type=int, default=config.NUM_AGENTS)
    p.add_argument("--days",   type=int, default=config.SIMULATION_DAYS)
    p.add_argument("--seed",   type=int, default=config.RANDOM_SEED)
    p.add_argument("--use-api", action="store_true", help="Fetch real POIs from Overpass API")
    p.add_argument("--out",    type=str, default=config.OUTPUT_DIR)
    return p.parse_args(argv)


def main(argv=None):
    args = parse_args(argv)

    # update config in-process
    config.NUM_AGENTS = args.agents
    config.SIMULATION_DAYS = args.days
    config.TOTAL_TICKS = args.days * config.TICKS_PER_DAY

    random.seed(args.seed)
    np.random.seed(args.seed)

    logger.info("=" * 70)
    logger.info("  PERSONA-CONDITIONED SMARTPHONE TELEMETRY SIMULATION")
    logger.info("=" * 70)
    logger.info(f"  agents : {args.agents}")
    logger.info(f"  days   : {args.days}")
    logger.info(f"  ticks  : {config.TOTAL_TICKS}")
    logger.info(f"  seed   : {args.seed}")
    logger.info(f"  out    : {args.out}")

    env = SimulationEnvironment(
        num_agents=args.agents,
        region=config.REGION,
        use_api=args.use_api,
        start_datetime=datetime(2024, 1, 1, 0, 0, 0),
    )
    env.create_agents(SmartphoneUser)

    try:
        env.run_simulation(total_ticks=config.TOTAL_TICKS)
    except KeyboardInterrupt:
        logger.warning("Interrupted by user")

    data_export.export_simulation_data(env, args.out)
    logger.info("Done.")
    return env


if __name__ == "__main__":
    main()
