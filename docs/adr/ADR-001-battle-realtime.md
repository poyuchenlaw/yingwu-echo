# ADR-001: Battle Real-Time Communication

Status: PROPOSED
Date: 2026-05-17

## Context

Battle sessions require near-real-time state sync between two players.
Options: WebSocket, HTTP SSE, HTTP Long-Poll.

## Decision

TBD — pending load estimation. Lean toward WebSocket via Gin upgrade
for bidirectional control messages; SSE for read-only state broadcast.

## Consequences

- WebSocket: requires sticky sessions or a message broker (Redis pub/sub)
- SSE: simpler, Flutter http package supports; no bidirectional control
- Long-poll: simplest, highest latency, easiest horizontal scaling

TODO: decide before milestone 2 backend sprint.
