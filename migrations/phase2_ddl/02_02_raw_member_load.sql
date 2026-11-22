
-- =============================================================
-- Design decisions:
--   1. All columns are VARCHAR — raw layer NEVER fails on bad data.
--   2. 12 positional COL_xx columns accommodate the widest source (original
--      feed, which yields 12 fields because a leading pipe creates an empty $1).
--      Narrower feeds (India=7, USA=6, Canada=5) leave the extra columns NULL.
--   3. SOURCE_FORMAT records which layout was used, allowing STG to apply the
--      correct column-position mapping and date-parse format.
--   4. RECORD_TYPE stores 'H'/'D' for the original feed and 'DATA' for CSV
--      feeds; STG filters to RECORD_TYPE IN ('D','DATA').
--   5. MEMBER_ID is the real business key (spec marks Member_Name as key —
--      that is a spec error; names are not unique. See README).
-- Column layout per SOURCE_FORMAT:
--   ORIGINAL : COL_01=empty  COL_02=REC_TYPE  COL_03=Member_Name
--              COL_04=Member_Id  COL_05=Enroll_Date  COL_06=Last_Flight_Date
--              COL_07=Tier_Code  COL_08=Agent_Name   COL_09=State
--              COL_10=Country    COL_11=DOB           COL_12=Is_Active
--   INDIA    : COL_01=ID  COL_02=Name  COL_03=DOB  COL_04=TierCode
--              COL_05=EnrollDate  COL_06=Individual  COL_07=FlightDate
--   USA      : COL_01=UniqueID  COL_02=MemberName  COL_03=TierType
--              COL_04=DOB  COL_05=EnrollDate  COL_06=FlightDate
--   CANADA   : COL_01=ID  COL_02=Name  COL_03=TierCode
--              COL_04=EnrollDate  COL_05=FlightDate
-- =============================================================

USE DATABASE SKYPOINTS_DB;
USE SCHEMA     RAW;
USE WAREHOUSE  WH_SKYPOINTS;

CREATE TABLE IF NOT EXISTS SKYPOINTS_DB.RAW.MEMBER_LOAD (
    -- Positional data columns (format-agnostic VARCHAR)
    COL_01          VARCHAR(500),
    COL_02          VARCHAR(500),
    COL_03          VARCHAR(500),
    COL_04          VARCHAR(500),
    COL_05          VARCHAR(500),
    COL_06          VARCHAR(500),
    COL_07          VARCHAR(500),
    COL_08          VARCHAR(500),
    COL_09          VARCHAR(500),
    COL_10          VARCHAR(500),
    COL_11          VARCHAR(500),
    COL_12          VARCHAR(500),
    -- Load metadata
    SOURCE_FILE     VARCHAR(500)    DEFAULT 'UNKNOWN',
    SOURCE_FORMAT   VARCHAR(50)     DEFAULT 'UNKNOWN',   -- ORIGINAL | INDIA | USA | CANADA
    RECORD_TYPE     VARCHAR(10),                         -- H | D | DATA
    LOAD_TS         TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    FILE_ROW_NUM    NUMBER
)
COMMENT = 'Raw landing for all member feeds — all VARCHAR, never rejects rows';
