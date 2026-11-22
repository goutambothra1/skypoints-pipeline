
-- Design decisions:
--   1. TXN_ID is the natural key for REDEMPTIONS_FLAT; the MERGE
--      in SP_LOAD_REDEMPTIONS uses it to handle re-sent transactions
--      and status transitions (PENDING → COMPLETED).
--   2. MILES_REDEEMED is validated > 0 in the DQ check and during
--      the MERGE; negative/zero values go to QUARANTINE.
--   3. STATUS must be in ('PENDING','COMPLETED','CANCELLED');
--      any other value routes the row to QUARANTINE.
--   4. REDEMPTIONS_QUARANTINE preserves the original VARIANT payload
--      for diagnosis and potential replay.
-- =============================================================

USE DATABASE SKYPOINTS_DB;
USE SCHEMA    CORE;
USE WAREHOUSE WH_SKYPOINTS;

-- -----------------------------------------------------------
-- CORE.REDEMPTIONS_FLAT — deduplicated, flattened transactions
-- -----------------------------------------------------------
CREATE TABLE IF NOT EXISTS SKYPOINTS_DB.CORE.REDEMPTIONS_FLAT (
    TXN_SK              NUMBER          AUTOINCREMENT PRIMARY KEY,
    TXN_ID              VARCHAR(50)     NOT NULL UNIQUE,  -- Natural key; MERGE target
    MEMBER_ID           VARCHAR(18)     NOT NULL,
    FEED_DATE           DATE,
    TXN_DATE            DATE,
    PARTNER             VARCHAR(100),
    MILES_REDEEMED      NUMBER,         -- Must be > 0; enforced in DQ / MERGE
    STATUS              VARCHAR(20),    -- PENDING | COMPLETED | CANCELLED
    SOURCE_FILE         VARCHAR(500),
    LOAD_TS             TIMESTAMP_NTZ,
    DW_INSERT_TS        TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    DW_UPDATE_TS        TIMESTAMP_NTZ
)
COMMENT = 'Flattened redemption transactions — MERGE on TXN_ID allows status updates';

-- -----------------------------------------------------------
-- CORE.REDEMPTIONS_QUARANTINE — orphan members + invalid rows
-- -----------------------------------------------------------
CREATE TABLE IF NOT EXISTS SKYPOINTS_DB.CORE.REDEMPTIONS_QUARANTINE (
    QUARANTINE_SK       NUMBER          AUTOINCREMENT PRIMARY KEY,
    RAW_RECORD          VARIANT,        -- Preserved for replay / diagnosis
    MEMBER_ID           VARCHAR(18),    -- Extracted for easy querying
    TXN_ID              VARCHAR(50),
    QUARANTINE_REASON   VARCHAR(2000),  -- e.g. ORPHAN_MEMBER | INVALID_STATUS | NEG_MILES
    SOURCE_FILE         VARCHAR(500),
    QUARANTINE_TS       TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Quarantine for orphan members and invalid redemption rows';
