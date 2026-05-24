"""
Generate Test Dataset
=====================

Generates a *separate* synthetic population intended for final evaluation
only. Uses cfg.RANDOM_SEED_TEST (different from training seed) and shifts
user_ids so they cannot collide with the training population.

This is critical for honest evaluation: training fits the model;
generate_training_data + train_catboost may overfit to specific synthetic
quirks; this held-out simulation lets us measure generalization to *new*
synthetic users (which is the closest analog to "new real users" we have).
"""

from __future__ import annotations

import logging
import random
import time

import numpy as np

import pipeline_config as cfg

import config as sim_cfg                          # noqa: E402
from environment import SimulationEnvironment    # noqa: E402
from agent import SmartphoneUser                  # noqa: E402
import data_export                                # noqa: E402

from generate_training_data import balanced_persona_distribution  # noqa: E402

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
)
log = logging.getLogger("gen_test")


def main():
    cfg.banner("GENERATE TEST DATASET (held-out)")
    log.info(f"  users:   {cfg.N_USERS_TEST}")
    log.info(f"  days:    {cfg.DAYS_PER_USER}")
    log.info(f"  seed:    {cfg.RANDOM_SEED_TEST}")
    log.info(f"  output:  {cfg.TEST_RAW_DIR}")

    random.seed(cfg.RANDOM_SEED_TEST)
    np.random.seed(cfg.RANDOM_SEED_TEST)

    sim_cfg.NUM_AGENTS = cfg.N_USERS_TEST
    sim_cfg.SIMULATION_DAYS = cfg.DAYS_PER_USER
    sim_cfg.TOTAL_TICKS = cfg.DAYS_PER_USER * sim_cfg.TICKS_PER_DAY

    persona_dist = balanced_persona_distribution() if cfg.BALANCE_PERSONAS else None

    t0 = time.time()
    env = SimulationEnvironment(
        num_agents=cfg.N_USERS_TEST,
        region=sim_cfg.REGION,
        use_api=False,
        persona_distribution=persona_dist,
    )
    env.create_agents(SmartphoneUser)
    log.info(f"environment + agents built in {time.time()-t0:.1f}s")

    # ---- shift user_ids so they don't collide with training (clarity / safety)
    USER_ID_OFFSET = 1_000_000
    for a in env.schedule.agents:
        a.unique_id += USER_ID_OFFSET

    t0 = time.time()
    env.run_simulation(total_ticks=sim_cfg.TOTAL_TICKS)
    log.info(f"simulation complete in {time.time()-t0:.1f}s")

    t0 = time.time()
    res = data_export.export_simulation_data(env, str(cfg.TEST_RAW_DIR))
    log.info(f"export complete in {time.time()-t0:.1f}s")
    for k, v in res.items():
        log.info(f"  {k:18s}: {v:,}")

    from collections import Counter
    breakdown = Counter(a.persona_id for a in env.schedule.agents)
    log.info("test population persona breakdown:")
    for pid, n in sorted(breakdown.items(), key=lambda x: -x[1]):
        log.info(f"  {pid:18s}: {n}")

    log.info("DONE.")


if __name__ == "__main__":
    main()
