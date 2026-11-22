
-- Design decisions:
--   1. MEMBER_ID (VARCHAR 18) is the natural key — spec incorrectly
--      lists Member_Name as the key column; names are not unique and
--      change over time. See README for the full assumption log.
--   2. AGE is birthday-aware: subtract 1 if the birthday has not yet
--      occurred this calendar year.
--   3. STALE_MEMBER defaults to 'Y' when LAST_FLIGHT_DATE IS NULL
--      (conservative — no recorded flight = treat as stale).
--   4. DQ_STATUS / DQ_REASON carry per-row quality flags set during
--      the STG load procedure; rows that fail mandatory-field or
--      type-cast checks are routed to MEMBER_REJECT instead.
--   5. MEMBER_TYPE stores India's Individual/Corporate flag (I/C);
--      NULL for all other source feeds.
--   6. COUNTRY stores the normalised ISO-3 code after COUNTRY_MAP lookup.
-- =============================================================

USE DATABASE SKYPOINTS_DB;
USE SCHEMA    STG;
USE WAREHOUSE WH_SKYPOINTS;

-- -----------------------------------------------------------
-- STG.MEMBER — cleansed, typed, deduped staging table
-- -----------------------------------------------------------
CREATE TABLE IF NOT EXISTS SKYPOINTS_DB.STG.MEMBER (
    -- Natural / business key
    MEMBER_ID           VARCHAR(18)     NOT NULL,
    -- Core attributes (typed)
    MEMBER_NAME         VARCHAR(200),
    ENROLLMENT_DATE     DATE,
    LAST_FLIGHT_DATE    DATE,
    TIER_CODE           VARCHAR(10),
    AGENT_NAME          VARCHAR(200),   -- May be NULL (optional field)
    STATE               VARCHAR(100),
    COUNTRY             VARCHAR(10),    -- Normalised ISO-3 via COUNTRY_MAP
    DOB                 DATE,
    IS_ACTIVE           BOOLEAN,
    MEMBER_TYPE         VARCHAR(1),     -- India only: I=Individual, C=Corporate
    -- Derived columns
    AGE                 NUMBER,         -- Birthday-aware full years as of load date
    STALE_MEMBER        VARCHAR(1),     -- 'Y' if days_since_last_flight > 90 or NULL
    -- Provenance
    SOURCE_FORMAT       VARCHAR(50),
    SOURCE_FILE         VARCHAR(500),
    LOAD_TS             TIMESTAMP_NTZ,
    FILE_ROW_NUM        NUMBER,
    -- Row-level DQ flags
    DQ_STATUS           VARCHAR(10),    -- PASS | WARN | FAIL
    DQ_REASON           VARCHAR(2000),  -- Pipe-separated list of failed rule IDs
    -- Warehouse audit
    DW_INSERT_TS        TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    DW_UPDATE_TS        TIMESTAMP_NTZ
)
COMMENT = 'Cleansed, typed staging layer — MEMBER_ID is the natural key';

-- -----------------------------------------------------------
-- STG.MEMBER_REJECT — rows that failed mandatory checks or
-- could not be type-cast; raw values preserved for diagnosis.
-- -----------------------------------------------------------
CREATE TABLE IF NOT EXISTS SKYPOINTS_DB.STG.MEMBER_REJECT (
    -- Raw values exactly as extracted from RAW (all VARCHAR)
    RAW_MEMBER_ID           VARCHAR(500),
    RAW_MEMBER_NAME         VARCHAR(500),
    RAW_ENROLLMENT_DATE     VARCHAR(500),
    RAW_LAST_FLIGHT_DATE    VARCHAR(500),
    RAW_TIER_CODE           VARCHAR(500),
    RAW_AGENT_NAME          VARCHAR(500),
    RAW_STATE               VARCHAR(500),
    RAW_COUNTRY             VARCHAR(500),
    RAW_DOB                 VARCHAR(500),
    RAW_IS_ACTIVE           VARCHAR(500),
    RAW_MEMBER_TYPE         VARCHAR(500),
    -- Provenance
    SOURCE_FORMAT           VARCHAR(50),
    SOURCE_FILE             VARCHAR(500),
    LOAD_TS                 TIMESTAMP_NTZ,
    FILE_ROW_NUM            NUMBER,
    -- Reject reason
    REJECT_REASON           VARCHAR(2000),
    REJECT_TS               TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Rows that failed mandatory-field or type-cast checks during STG load';
