-- =============================================================
-- SkyPoints Loyalty Pipeline
-- Phase 1 | Step 3 — Schemas
-- Idempotent: safe to re-run
-- =============================================================

USE DATABASE SKYPOINTS_DB;
USE WAREHOUSE WH_SKYPOINTS;

-- RAW  : flat-file landing zone (pipe-delimited members, future feeds)
CREATE SCHEMA IF NOT EXISTS SKYPOINTS_DB.RAW
    COMMENT = 'Raw landing layer — files ingested as-is';

-- STG  : cleansed, type-cast, deduplicated source data
CREATE SCHEMA IF NOT EXISTS SKYPOINTS_DB.STG
    COMMENT = 'Staged / cleansed layer';

-- CORE : dimensional model (facts, dimensions)
CREATE SCHEMA IF NOT EXISTS SKYPOINTS_DB.CORE
    COMMENT = 'Dimensional model layer';

-- DQ   : data-quality rule results and audit logs
CREATE SCHEMA IF NOT EXISTS SKYPOINTS_DB.DQ
    COMMENT = 'Data quality layer';
