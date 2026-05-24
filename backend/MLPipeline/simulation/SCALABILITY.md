# Scalability Strategy

How the persona-conditioned synthetic telemetry simulator scales from
prototype runs to large-population production datasets.

---

## 1. Compute profile (current implementation)

Each tick costs O(N_agents). Per agent, per tick:

| Cost source | Approx ops |
|---|---|
| Internal-state update | ~10 ops |
| Episode utility scoring | 15 episode types × ~20 ops |
| Episode FSM tick (already-locked) | 1 callback |
| Telemetry generation | 1 GPS sample (every N ticks), 1 app session, ≤1 screen event |

Empirical: **100 agents × 7 days (2 016 ticks) ≈ 18 s** on a single laptop CPU
core. Linear in `agents × ticks`.

| Pop size | Days | Ticks | Wall time | Output rows (gps+app) |
|---|---|---|---|---|
| 100 | 7 | 200 K | ~18 s | ~170 K |
| 1 000 | 7 | 2 M | ~3 min | ~1.7 M |
| 10 000 | 30 | 86 M | ~2 h | ~70 M |
| 100 000 | 30 | 860 M | ~20 h | ~700 M |

These are single-process estimates. With sharding (see §3) the wall time
collapses near-linearly with cores.

---

## 2. Memory budget

Each event row:

| Stream | Bytes/row (approx) | Rate (per agent-day) |
|---|---|---|
| gps_ping | 80 B | ~144 (every 10 min) |
| app_session | 80 B | ~120 (per active tick) |
| screen_event | 50 B | ~30 (incl. notifications) |
| episode_log | 120 B | ~7 |

For 10 000 agents × 30 days held entirely in RAM ≈ **6-8 GB** for the
buffers. Above that, switch to chunked-write mode (§4).

---

## 3. Parallel sharding

The simulation is **embarrassingly parallel across user shards**: agents
share an immutable POI environment but otherwise have no cross-agent
state (no co-location coupling in the current model).

Recommended pattern:

```python
# spawn N processes; each runs an independent SimulationEnvironment
#   on a disjoint user_id range with the same POI seed.
from multiprocessing import Pool

def run_shard(shard_id, num_agents, days, seed_offset):
    random.seed(BASE_SEED + seed_offset)
    env = SimulationEnvironment(num_agents=num_agents, ...)
    env.create_agents(SmartphoneUser)
    env.run_simulation(total_ticks=days * TICKS_PER_DAY)
    # write per-shard CSVs to out/shard_{shard_id}/
    data_export.export_simulation_data(env, f"out/shard_{shard_id}")

with Pool(NUM_CORES) as p:
    p.starmap(run_shard, [(i, 1000, 30, i*1000) for i in range(NUM_CORES)])
```

After all shards finish, concatenate (small post-processing job):

```bash
csvstack out/shard_*/gps_pings.csv > out/gps_pings.csv
# etc.
```

For very large jobs use **Dask** instead — same pattern but results stream
to parquet partitions automatically.

> **Cross-agent coupling caveat:** if you later add social-graph features
> (eg "friends meet up"), shards must share a coordination layer. The
> current model has no such coupling, so sharding is safe.

---

## 4. Chunked / streaming export

For datasets that don't fit in RAM, replace the in-memory buffers with
on-the-fly writers:

```python
class StreamingEnvironment(SimulationEnvironment):
    def __init__(self, *, output_dir, **kw):
        super().__init__(**kw)
        self._gps_writer  = csv.DictWriter(open(f"{output_dir}/gps_pings.csv","w"), ...)
        self._gps_writer.writeheader()
        # ... same for the other streams

    def add_gps_ping(self, *args, **kw):
        # write directly instead of appending to self.gps_pings
        ...
```

This is a ~30-line patch. Use it for `agents × days > 50 000`.

For columnar workloads (downstream Spark / DuckDB queries), write
**parquet** in fixed-row partitions (`pyarrow.ParquetWriter`).

---

## 5. Geography scaling

The current `osm_integration` fetches all POIs in a 20×20 km box. For
multi-city or country-scale runs:

1. Pre-cache POIs to local SQLite/parquet keyed by region.
2. Each agent gets a "region of residence" assigned at population time;
   the agent only sees POIs within that region's box.
3. Run one shard per region in parallel.

---

## 6. Batched downstream pipelines

`ml_features.csv` is computed with one pass over each per-user slice of
the in-memory buffers. For large runs, replace with **DuckDB**:

```sql
COPY (
  SELECT user_id,
         category,
         SUM(duration_min) AS total_min
  FROM   read_csv_auto('out/shard_*/app_sessions.csv')
  GROUP  BY user_id, category
) TO 'features_app_categories.parquet';
```

DuckDB ingests parquet at GB/s on a laptop. Same pattern works for
hourly_activity.

---

## 7. Reproducibility under parallelism

Each shard seeds its RNG with `BASE_SEED + shard_id`. The POI environment
is rebuilt deterministically from `RANDOM_SEED` so all shards see the
same world. `user_id` is `shard_id * AGENTS_PER_SHARD + local_id` so IDs
never collide.

---

## 8. Knobs you can tune for speed without losing fidelity

| Knob (in `config.py`) | Effect |
|---|---|
| `TICK_DURATION_MINUTES` (5 → 10) | Halves wall time, halves resolution |
| `GPS_SAMPLING_INTERVAL_MINUTES` (10 → 15) | Cuts GPS rows by 33 % |
| `POI_CATEGORIES[*]['count_target']` | Smaller POI sets → faster nearest-POI lookup |
| Episode FSM steps' `duration_ticks` | Coarser episodes → fewer telemetry events |

For ML training, 15-minute GPS resolution is usually sufficient.

---

## 9. Production deployment shape (recommendation)

```
       ┌──────────────────────────────────────┐
       │   orchestrator (Airflow / Argo)       │
       │   schedules a shard-run DAG nightly   │
       └────────────────┬─────────────────────┘
                        │
            ┌───────────┴────────────┐
            ▼                        ▼
       shard-runner pod        shard-runner pod   …  (N pods)
       (simulate.py)           (simulate.py)
            │                        │
            └────────► object store ◄┘
                       (S3 / GCS, parquet)
                              │
                              ▼
                       DuckDB / Spark job:
                       • ml_features.parquet
                       • hourly_activity.parquet
                              │
                              ▼
                       persona model trainer
                       (LightGBM / Transformer)
```

Each shard runner is stateless and idempotent (seed-driven). Failure
recovery = re-run the failed shard.

---

## TL;DR

- **Linear scaling** in `agents × ticks` — single laptop handles 10k agents × 30 days in a couple of hours.
- **Embarrassingly parallel** by user-shard — drop in `multiprocessing.Pool` or Dask for near-linear speedup.
- **Streaming export** for >50k populations to keep memory flat.
- **Parquet + DuckDB** for downstream ML feature computation.
