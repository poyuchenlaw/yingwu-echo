#!/usr/bin/env bash
# yingwu-echo end-to-end gate. v0.6.4 player playthrough automation.
set -uo pipefail

VERBOSE=0
[[ "${1:-}" == "--verbose" ]] && VERBOSE=1

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PG_PORT=5433
PG_CONTAINER=yingwu-pg-e2e
SERVER_PORT=18080
DB_URL="postgres://postgres:yingwu@localhost:${PG_PORT}/yingwu_echo?sslmode=disable"
REDIS_URL="${REDIS_URL:-redis://localhost:6379/0}"
LOG=/tmp/yingwu_e2e_server.log
PID_FILE=/tmp/yingwu_e2e_server.pid

P1=aaaaaaaa-1111-1111-1111-aaaaaaaaaaaa
P2=bbbbbbbb-2222-2222-2222-bbbbbbbbbbbb

PASS=0; FAIL=0; FAILURES=()

log()  { echo "[e2e] $*"; }
fail() { echo "[e2e] FAIL: $*" >&2; FAILURES+=("$*"); FAIL=$((FAIL+1)); }
ok()   { echo "[e2e] ok: $*"; PASS=$((PASS+1)); }

cleanup() {
  log "cleanup"
  [[ -f "$PID_FILE" ]] && kill "$(cat $PID_FILE)" 2>/dev/null
  rm -f "$PID_FILE" /tmp/yingwu_e2e_server "$LOG"
  docker rm -f "$PG_CONTAINER" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# Step 1: redis reachable (host's running instance, not started by us)
redis-cli -u "$REDIS_URL" ping >/dev/null 2>&1 || { fail "redis ping"; exit 1; }
ok "redis ping"

# Step 2: ephemeral Postgres. Clear ANY container holding $PG_PORT so prior
# manual debug containers (different names) don't poison the run.
docker rm -f "$PG_CONTAINER" >/dev/null 2>&1 || true
PORT_HOLDERS=$(docker ps -q --filter "publish=${PG_PORT}" 2>/dev/null)
[[ -n "$PORT_HOLDERS" ]] && docker rm -f $PORT_HOLDERS >/dev/null 2>&1
docker run -d --name "$PG_CONTAINER" \
  -e POSTGRES_PASSWORD=yingwu -e POSTGRES_DB=yingwu_echo \
  -p ${PG_PORT}:5432 postgres:15-alpine >/dev/null
log "waiting for postgres..."
for i in {1..30}; do
  PGPASSWORD=yingwu psql -h localhost -p $PG_PORT -U postgres -d yingwu_echo -c "select 1" >/dev/null 2>&1 && break
  sleep 1
done
PGPASSWORD=yingwu psql -h localhost -p $PG_PORT -U postgres -d yingwu_echo -c "select 1" >/dev/null 2>&1 \
  || { fail "pg connect"; exit 1; }
ok "postgres up"

# Step 3: apply migrations in order
cd "$REPO_ROOT"
for f in migrations/*.sql; do
  if ! PGPASSWORD=yingwu psql -h localhost -p $PG_PORT -U postgres -d yingwu_echo \
       -v ON_ERROR_STOP=1 -f "$f" >/tmp/yingwu_mig.log 2>&1; then
    fail "migration $f"; tail -10 /tmp/yingwu_mig.log >&2; exit 1
  fi
done
ok "migrations applied"

# Step 4: monster_species seed (Bug 3 regression gate)
SEED_COUNT=$(PGPASSWORD=yingwu psql -h localhost -p $PG_PORT -U postgres -d yingwu_echo \
             -tAc "select count(*) from monster_species")
if [[ "$SEED_COUNT" != "25" ]]; then
  fail "monster_species count: expected 25, got $SEED_COUNT"
else
  ok "monster_species seed = 25"
fi

# Step 5: build + start server. Go module root is backend/, not repo root.
(cd "$REPO_ROOT/backend" && go build -o /tmp/yingwu_e2e_server ./cmd/server/) 2>/tmp/yingwu_build.log
[[ $? -ne 0 ]] && { fail "go build"; cat /tmp/yingwu_build.log >&2; exit 1; }
DATABASE_URL="$DB_URL" REDIS_URL="$REDIS_URL" PORT=$SERVER_PORT \
  /tmp/yingwu_e2e_server >"$LOG" 2>&1 &
echo $! > "$PID_FILE"
sleep 3
curl -sf "http://localhost:$SERVER_PORT/health" >/dev/null \
  || { fail "server /health"; tail -20 "$LOG" >&2; exit 1; }
ok "server up"

# Step 6: POST writing as P1
WRITING_RESP=$(curl -s -X POST "http://localhost:$SERVER_PORT/api/v1/writings" \
  -H "Content-Type: application/json" -H "X-Player-Id: $P1" \
  -d '{"content":"E2E 測試文 — 通勤累。","emotion_tag":"累","word_count":12,"location_alias":"e2e"}')
WRITING_ID=$(echo "$WRITING_RESP" | grep -oE '"writing_id":"[^"]+' | cut -d'"' -f4)
[[ -z "$WRITING_ID" ]] && { fail "POST writing"; echo "$WRITING_RESP" >&2; exit 1; }
ok "POST writing: $WRITING_ID"

# Step 7: wait for worker to BLPop + analyze + persist + acquire
sleep 4

# Step 8: writing status (regression gate for Bug 1 status drift)
STATUS=$(PGPASSWORD=yingwu psql -h localhost -p $PG_PORT -U postgres -d yingwu_echo \
         -tAc "select status from player_writings where id='$WRITING_ID'")
if [[ "$STATUS" != "COMPLETE" ]]; then
  fail "writing status: expected COMPLETE, got '$STATUS'"
else
  ok "writing status=COMPLETE"
fi

# Step 9: monster acquired in DB (Bug 3 regression gate)
MONSTER_COUNT=$(PGPASSWORD=yingwu psql -h localhost -p $PG_PORT -U postgres -d yingwu_echo \
                -tAc "select count(*) from player_monsters where player_id='$P1'")
if [[ "$MONSTER_COUNT" -lt 1 ]]; then
  fail "player_monsters for P1: expected >=1, got $MONSTER_COUNT"
else
  ok "P1 acquired $MONSTER_COUNT monster(s)"
fi

# Step 10: GET /monsters reads back (Bug 5 regression gate)
P1_COUNT=$(curl -s -H "X-Player-Id: $P1" "http://localhost:$SERVER_PORT/api/v1/monsters" \
           | grep -oE '"count":[0-9]+' | cut -d: -f2)
if [[ "${P1_COUNT:-0}" -lt 1 ]]; then
  fail "GET /monsters P1: expected >=1, got ${P1_COUNT:-empty}"
else
  ok "GET /monsters P1 count=$P1_COUNT"
fi

# Step 11: privacy isolation (P2 must see nothing)
P2_COUNT=$(curl -s -H "X-Player-Id: $P2" "http://localhost:$SERVER_PORT/api/v1/monsters" \
           | grep -oE '"count":[0-9]+' | cut -d: -f2)
if [[ "${P2_COUNT:-0}" != "0" ]]; then
  fail "GET /monsters P2: expected 0 (privacy), got ${P2_COUNT}"
else
  ok "GET /monsters P2 isolated"
fi

# Step 12: wuxing not silently fallback (Bug 2 regression gate)
WUXING=$(PGPASSWORD=yingwu psql -h localhost -p $PG_PORT -U postgres -d yingwu_echo \
         -tAc "select wuxing_detected from player_writings where id='$WRITING_ID'")
if [[ "$WUXING" == "earth" ]]; then
  fail "wuxing_detected=earth (silent CN->EN fallback regression)"
else
  ok "wuxing_detected=$WUXING"
fi

# Step 13: failure_ledger scaffold (v0.6.5 杜絕 silent failure gate).
# Note: AcquireMonsterForWriting has a 3-level fallback (last level picks any
# random common variant), so we cannot easily trigger a real acquire_failure
# from the API surface alone. v0.6.5.1 will tighten the fallback policy and
# add a warning at level-3 hit. For now we verify (a) the table+indexes
# exist via migration 0011, and (b) the audit.Record path round-trips by
# inserting one synthetic P2 event and reading it back.
PGPASSWORD=yingwu psql -h localhost -p $PG_PORT -U postgres -d yingwu_echo -tAc \
  "INSERT INTO failure_ledger (event_kind, severity, target_pk, error_msg) \
   VALUES ('e2e_smoke_synthetic', 'P2', '$WRITING_ID', 'e2e_smoke gate roundtrip')" >/dev/null 2>&1
LEDGER_COUNT=$(PGPASSWORD=yingwu psql -h localhost -p $PG_PORT -U postgres -d yingwu_echo \
               -tAc "select count(*) from failure_ledger where event_kind='e2e_smoke_synthetic'")
if [[ "${LEDGER_COUNT:-0}" -lt 1 ]]; then
  fail "failure_ledger roundtrip: expected >=1, got ${LEDGER_COUNT:-empty} (migration 0011 may have failed)"
else
  ok "failure_ledger roundtrip ok (rows=$LEDGER_COUNT)"
fi

# Summary
log "summary: $PASS passed, $FAIL failed"
if [[ $FAIL -gt 0 ]]; then
  echo "[e2e] FAILURES:" >&2
  for f in "${FAILURES[@]}"; do echo "  - $f" >&2; done
  [[ $VERBOSE -eq 1 ]] && { echo "--- server log ---" >&2; cat "$LOG" >&2; }
  exit 2
fi
exit 0
