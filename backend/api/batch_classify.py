"""
One-time batch persona classification for all users.

Usage (from backend/api/):
    python batch_classify.py
    python batch_classify.py --force    # re-classify even if cache is fresh
"""

from __future__ import annotations

import argparse
import sys
import time

# Import from main — loads model, env vars, Supabase headers at import time
from main import _classify, _supa_get


def fetch_all_user_ids() -> list[str]:
    rows = _supa_get("users", {"select": "id"})
    return [r["id"] for r in rows if r.get("id")]


def run(force: bool) -> None:
    user_ids = fetch_all_user_ids()
    total = len(user_ids)
    print(f"\n{'='*60}")
    print(f"  Batch Persona Classification - {total} users  (force={force})")
    print(f"{'='*60}\n")

    results: list[dict] = []
    errors: list[tuple[str, str]] = []

    for i, uid in enumerate(user_ids, 1):
        try:
            t0 = time.time()
            persona_class, meta, signals_today, _ = _classify(uid, force=force)
            elapsed = time.time() - t0
            results.append({
                "user_id": uid,
                "persona": persona_class,
                "display": meta["display"],
                "signals_today": signals_today,
                "elapsed_s": round(elapsed, 2),
            })
            print(f"[{i:>2}/{total}] {uid[:8]}...  ->  {persona_class:<20} ({elapsed:.2f}s)")
        except Exception as e:
            errors.append((uid, str(e)))
            print(f"[{i:>2}/{total}] {uid[:8]}...  ->  ERROR: {e}", file=sys.stderr)

    # Summary
    print(f"\n{'='*60}")
    print(f"  Done: {len(results)} classified, {len(errors)} errors")
    print(f"{'='*60}")

    if results:
        from collections import Counter
        dist = Counter(r["persona"] for r in results)
        print("\nPersona distribution:")
        for persona, count in sorted(dist.items(), key=lambda x: -x[1]):
            bar = "#" * count
            print(f"  {persona:<22} {count:>3}  {bar}")

    if errors:
        print("\nErrors:")
        for uid, msg in errors:
            print(f"  {uid}: {msg}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--force", action="store_true",
                        help="Bypass 24h cache and re-run model for every user")
    args = parser.parse_args()
    run(force=args.force)
