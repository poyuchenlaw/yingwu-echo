-- v0.6.5: failure_ledger — audit table for served-path silent failures.
-- Every P0/P1/P2 event that was previously swallowed by log.Printf now lands here,
-- enabling trace, alerting, and remediability review per LV0 "杜絕安靜失敗".

CREATE TABLE IF NOT EXISTS failure_ledger (
    event_id      uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
    event_kind    varchar(64) NOT NULL,
    severity      varchar(16) NOT NULL,          -- P0 (high) / P1 (warn) / P2 (info)
    env           varchar(16) NOT NULL DEFAULT 'served',
    occurred_at   timestamptz NOT NULL DEFAULT now(),
    actor_id      uuid,
    target_pk     varchar(80),
    error_code    varchar(64),
    error_msg     text,
    context_json  jsonb,
    retry_count   int         NOT NULL DEFAULT 0,
    resolved_at   timestamptz,
    resolved_by   varchar(80)
);

-- Fast lookup by kind + time (worker drain monitoring)
CREATE INDEX IF NOT EXISTS idx_failure_ledger_kind_time
    ON failure_ledger (event_kind, occurred_at DESC);

-- Fast lookup by affected row (e.g. writing_id)
CREATE INDEX IF NOT EXISTS idx_failure_ledger_target
    ON failure_ledger (target_pk);

-- Unresolved high/warn events dashboard
CREATE INDEX IF NOT EXISTS idx_failure_ledger_sev_unresolved
    ON failure_ledger (severity, occurred_at DESC)
    WHERE resolved_at IS NULL;
