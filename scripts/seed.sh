#!/usr/bin/env bash
# seed.sh — batch-insert monster variants and faction skills
# Usage: DB_URL=postgres://... bash scripts/seed.sh

set -euo pipefail

DB_URL="${DB_URL:-postgres://localhost/yingwu_echo_dev}"

echo "[seed] Starting monster species seed..."
for f in data/monsters/*.json; do
  echo "  -> $f"
  # TODO: replace with proper upsert CLI tool or Go seed binary
  # psql "$DB_URL" -c "\copy monster_variants FROM PROGRAM 'cat $f' ..."
  echo "  (placeholder: wire to Go seed binary)"
done

echo "[seed] Starting faction skills seed..."
if [ -f data/seed/factions.json ]; then
  echo "  -> data/seed/factions.json (placeholder)"
fi

echo "[seed] Done."
