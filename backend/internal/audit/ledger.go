package audit

import (
	"context"
	"database/sql"
	"encoding/json"
	"log"
	"time"

	"github.com/google/uuid"
)

const (
	P0 = "P0"
	P1 = "P1"
	P2 = "P2"
)

type Event struct {
	EventKind   string
	Severity    string
	Env         string
	OccurredAt  time.Time
	ActorID     *uuid.UUID
	TargetPK    string
	ErrorCode   string
	ErrorMsg    string
	ContextJSON map[string]any
	RetryCount  int
}

func Record(ctx context.Context, db *sql.DB, ev Event) error {
	ev = withDefaults(ev)
	if db == nil {
		logFallback(ev)
		return nil
	}

	var ctxJSON any
	if ev.ContextJSON != nil {
		b, err := json.Marshal(ev.ContextJSON)
		if err != nil {
			log.Printf("audit_event: context_json marshal failed kind=%s err=%v", ev.EventKind, err)
		} else {
			ctxJSON = string(b)
		}
	}
	var actorID any
	if ev.ActorID != nil {
		actorID = *ev.ActorID
	}
	nullable := func(s string) any {
		if s == "" {
			return nil
		}
		return s
	}

	_, err := db.ExecContext(ctx, `
		INSERT INTO failure_ledger
		(event_kind, severity, env, occurred_at, actor_id, target_pk, error_code, error_msg, context_json, retry_count)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9::jsonb,$10)`,
		ev.EventKind, ev.Severity, ev.Env, ev.OccurredAt, actorID,
		nullable(ev.TargetPK), nullable(ev.ErrorCode), nullable(ev.ErrorMsg), ctxJSON, ev.RetryCount,
	)
	if err != nil {
		log.Printf("audit_event: ledger insert failed kind=%s severity=%s err=%v", ev.EventKind, ev.Severity, err)
		logFallback(ev)
		return err
	}
	return nil
}

func RecordKind(ctx context.Context, db *sql.DB, kind, severity, targetPK, errMsg string, ctxJSON map[string]any) error {
	return Record(ctx, db, Event{
		EventKind:   kind,
		Severity:    severity,
		TargetPK:    targetPK,
		ErrorMsg:    errMsg,
		ContextJSON: ctxJSON,
	})
}

func MarkResolved(ctx context.Context, db *sql.DB, eventID uuid.UUID, resolvedBy string) error {
	if db == nil {
		log.Printf("audit_event: mark_resolved event_id=%s resolved_by=%s", eventID, resolvedBy)
		return nil
	}
	_, err := db.ExecContext(ctx, `UPDATE failure_ledger SET resolved_at=now(), resolved_by=$1 WHERE event_id=$2`, resolvedBy, eventID)
	return err
}

func logFallback(ev Event) {
	ev = withDefaults(ev)
	ctxJSON, err := json.Marshal(ev.ContextJSON)
	if err != nil {
		ctxJSON = []byte(`{"marshal_error":true}`)
	}
	actorID := any(nil)
	if ev.ActorID != nil {
		actorID = *ev.ActorID
	}
	log.Printf(
		"audit_event: event_kind=%s severity=%s env=%s occurred_at=%s actor_id=%v target_pk=%s error_code=%s error_msg=%q context_json=%s retry_count=%d",
		ev.EventKind, ev.Severity, ev.Env, ev.OccurredAt.Format(time.RFC3339Nano),
		actorID, ev.TargetPK, ev.ErrorCode, ev.ErrorMsg, string(ctxJSON), ev.RetryCount,
	)
}

func withDefaults(ev Event) Event {
	if ev.Env == "" {
		ev.Env = "served"
	}
	if ev.OccurredAt.IsZero() {
		ev.OccurredAt = time.Now().UTC()
	}
	return ev
}
