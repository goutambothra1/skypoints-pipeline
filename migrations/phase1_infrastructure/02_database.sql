-- =============================================================
-- SkyPoints Loyalty Pipeline
-- Phase 1 | Step 2 — Database
-- Idempotent: safe to re-run
-- =============================================================

CREATE DATABASE IF NOT EXISTS SKYPOINTS_DB
    COMMENT = 'SkyPoints airline loyalty pipeline';
