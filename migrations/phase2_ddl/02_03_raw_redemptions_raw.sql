
-- Design decisions:
--   VARIANT column stores the entire NDJSON object verbatim.
--   Flattening and validation happen in Phase 7 (LATERAL FLATTEN
--   into CORE.REDEMPTIONS_FLAT) so the raw layer preserves the
--   exact original payload for audit and re-processing.
-- =============================================================

USE DATABASE SKYPOINTS_DB;
USE SCHEMA    RAW;
USE WAREHOUSE WH_SKYPOINTS;

CREATE TABLE IF NOT EXISTS SKYPOINTS_DB.RAW.REDEMPTIONS_RAW (
    RAW_RECORD      VARIANT,                            -- Full NDJSON object
    SOURCE_FILE     VARCHAR(500)    DEFAULT 'UNKNOWN',
    LOAD_TS         TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    FILE_ROW_NUM    NUMBER
)
COMMENT = 'Raw landing for NDJSON redemptions feed — VARIANT, never rejects rows';
