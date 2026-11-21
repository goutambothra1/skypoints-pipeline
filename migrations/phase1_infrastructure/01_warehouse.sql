-- =============================================================
-- SkyPoints Loyalty Pipeline
-- Phase 1 | Step 1 — Warehouse
-- Idempotent: safe to re-run
-- =============================================================

CREATE WAREHOUSE IF NOT EXISTS WH_SKYPOINTS
    WAREHOUSE_SIZE      = 'X-SMALL'
    AUTO_SUSPEND        = 60
    AUTO_RESUME         = TRUE
    INITIALLY_SUSPENDED = TRUE
    COMMENT             = 'SkyPoints pipeline warehouse';
