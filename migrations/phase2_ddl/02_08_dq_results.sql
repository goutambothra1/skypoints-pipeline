
-- Design decisions:
--   One row per rule per pipeline run (batch-level granularity).
--   FAIL_COUNT = 0 → STATUS = PASS.
--   FAIL_COUNT > 0 but below threshold → STATUS = WARN.
--   FAIL_COUNT above threshold or critical rule → STATUS = FAIL.
--   The row-count reconciliation rule (raw = staging + rejects)
--   is stored here as RULE_ID = 'RECONCILE_ROW_COUNT'.
-- =============================================================

USE DATABASE SKYPOINTS_DB;
USE SCHEMA    DQ;
USE WAREHOUSE WH_SKYPOINTS;

CREATE TABLE IF NOT EXISTS SKYPOINTS_DB.DQ.DQ_RESULTS (
    DQ_SK           NUMBER          AUTOINCREMENT PRIMARY KEY,
    RUN_TS          TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    RULE_ID         VARCHAR(100)    NOT NULL,   -- e.g. NOT_NULL_MEMBER_ID
    RULE_DESC       VARCHAR(500),
    LAYER           VARCHAR(20),               -- RAW | STG | CORE | JSON
    TABLE_NAME      VARCHAR(200),
    PASS_COUNT      NUMBER          DEFAULT 0,
    FAIL_COUNT      NUMBER          DEFAULT 0,
    WARN_COUNT      NUMBER          DEFAULT 0,
    TOTAL_COUNT     NUMBER          DEFAULT 0,
    STATUS          VARCHAR(10),               -- PASS | WARN | FAIL
    NOTES           VARCHAR(2000)
)
COMMENT = 'DQ rule results — one row per rule per pipeline run';
