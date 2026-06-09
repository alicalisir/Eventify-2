"""
Generate Training Dataset
=========================

Drives the simulator (FakeData/simulation/) with the *training* seed and
writes raw CSVs to outputs/train_raw/. Persona sampling is balanced when
cfg.BALANCE_PERSONAS = True so supervised learning has enough examples per
class.

This script does NOT do feature engineering. The training script reads the
raw CSVs through `feature_engineering.features_from_directory(...)`. That
guarantees feature parity with real-world inference.

Run:
    python generate_training_data.py
    N_USERS_TRAIN=2000 DAYS_PER_USER=30 python generate_training_data.py
"""

from __future__ import annotations

import logging
import random
import sys
import time
from pathlib import Path

import numpy as np

# Load pipeline config — also pushes simulator path onto sys.path
import pipeline_config as cfg

# Now we can import the simulator (its `config` module is the simulator's
# config.py because pipeline_config didn't claim that name).
import config as sim_cfg                          # noqa: E402  simulator config
from environment import SimulationEnvironment    # noqa: E402
from agent import SmartphoneUser                  # noqa: E402
import data_export                                # noqa: E402

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
)
log = logging.getLogger("gen_train")


def balanced_persona_distribution() -> dict:
    """Uniform 1/12 across all 12 personas."""
    persona_ids = [
        "NIGHT_OWL", "EARLY_BIRD", "SOCIAL", "GAMER", "CONTENT_CONSUMER",
        "ATHLETE", "STUDENT", "PROFESSIONAL", "HOMEBODY", "TRAVELER",
        "IRREGULAR", "HYBRID",
    ]
    return {pid: 1.0 / len(persona_ids) for pid in persona_ids}


def main():
    cfg.banner("GENERATE TRAINING DATASET")
    log.info(f"  users:   {cfg.N_USERS_TRAIN}")
    log.info(f"  days:    {cfg.DAYS_PER_USER}")
    log.info(f"  seed:    {cfg.RANDOM_SEED_TRAIN}")
    log.info(f"  balance: {cfg.BALANCE_PERSONAS}")
    log.info(f"  output:  {cfg.TRAIN_RAW_DIR}")

    # determinism
    random.seed(cfg.RANDOM_SEED_TRAIN)
    np.random.seed(cfg.RANDOM_SEED_TRAIN)

    # patch simulator config in-process
    sim_cfg.NUM_AGENTS     = cfg.N_USERS_TRAIN
    sim_cfg.SIMULATION_DAYS = cfg.DAYS_PER_USER
    sim_cfg.TOTAL_TICKS    = cfg.DAYS_PER_USER * sim_cfg.TICKS_PER_DAY

    # build env
    persona_dist = balanced_persona_distribution() if cfg.BALANCE_PERSONAS else None
    t0 = time.time()
    env = SimulationEnvironment(
        num_agents=cfg.N_USERS_TRAIN,
        region=sim_cfg.REGION,
        use_api=False,
        persona_distribution=persona_dist,
    )
    env.create_agents(SmartphoneUser)
    log.info(f"environment + agents built in {time.time()-t0:.1f}s")

    # run
    t0 = time.time()
    env.run_simulation(total_ticks=sim_cfg.TOTAL_TICKS)
    log.info(f"simulation complete in {time.time()-t0:.1f}s")

    # export
    t0 = time.time()
    res = data_export.export_simulation_data(env, str(cfg.TRAIN_RAW_DIR))
    log.info(f"export complete in {time.time()-t0:.1f}s")
    for k, v in res.items():
        log.info(f"  {k:18s}: {v:,}")

    # persona breakdown
    from collections import Counter
    breakdown = Counter(a.persona_id for a in env.schedule.agents)
    log.info("training population persona breakdown:")
    for pid, n in sorted(breakdown.items(), key=lambda x: -x[1]):
        log.info(f"  {pid:18s}: {n}")

    log.info("DONE.")


if __name__ == "__main__":
    main()
