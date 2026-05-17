-- migrations/0003_player_faction_memberships.sql
-- yingwu-echo v0.4 patch — faction DAO referenced this table but 0002 missed it
-- PostgreSQL 16
-- Executed via: psql yingwu_echo_dev < migrations/0003_player_faction_memberships.sql

BEGIN;

CREATE TABLE player_faction_memberships (
    player_id    UUID         PRIMARY KEY,
    faction_id   UUID         NOT NULL REFERENCES player_factions(id) ON DELETE RESTRICT,
    joined_at    TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_player_faction_memberships_faction ON player_faction_memberships(faction_id);

COMMIT;
-- END: 0003_player_faction_memberships.sql
