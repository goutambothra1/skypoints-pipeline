-- =============================================================
-- SkyPoints Loyalty Pipeline
-- Phase 3 / 4 — COPY INTO RAW (all source feeds)
-- Idempotent: Snowflake tracks loaded files; FORCE=FALSE (default)
-- means already-loaded files are skipped on re-run.
-- ON_ERROR=CONTINUE: bad rows are skipped and logged; the load
-- never fails the entire file.
-- =============================================================

USE DATABASE SKYPOINTS_DB;
USE WAREHOUSE WH_SKYPOINTS;

-- -----------------------------------------------------------
-- 1. Original pipe-delimited feed (12 positional columns)
--    $1 = empty (leading pipe)   $2 = REC_TYPE (H|D)
--    $3 = Member_Name            $4 = Member_Id
--    $5 = Enrollment_Date        $6 = Last_Flight_Date
--    $7 = Tier_Code              $8 = Agent_Name
--    $9 = State                  $10 = Country
--    $11 = DOB                   $12 = Is_Active
--    RECORD_TYPE is taken directly from $2 so H and D rows are
--    both stored; STG filters to RECORD_TYPE = 'D'.
-- -----------------------------------------------------------
COPY INTO SKYPOINTS_DB.RAW.MEMBER_LOAD
    (COL_01,COL_02,COL_03,COL_04,COL_05,COL_06,
     COL_07,COL_08,COL_09,COL_10,COL_11,COL_12,
     SOURCE_FILE, SOURCE_FORMAT, RECORD_TYPE, FILE_ROW_NUM)
FROM (
    SELECT
        $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,
        METADATA$FILENAME,
        'ORIGINAL',
        $2,                 -- H or D
        METADATA$FILE_ROW_NUMBER
    FROM @SKYPOINTS_DB.RAW.STG_MEMBER_ORIGINAL
)
FILE_FORMAT = (FORMAT_NAME = SKYPOINTS_DB.RAW.FF_MEMBER_PIPE)
ON_ERROR    = CONTINUE;

-- -----------------------------------------------------------
-- 2. India feed — 7 columns (ID,Name,DOB,TierCode,
--    EnrollDate,Individual,FlightDate)
--    COL_08..COL_12 intentionally NULL (not in this feed).
-- -----------------------------------------------------------
COPY INTO SKYPOINTS_DB.RAW.MEMBER_LOAD
    (COL_01,COL_02,COL_03,COL_04,COL_05,COL_06,COL_07,
     SOURCE_FILE, SOURCE_FORMAT, RECORD_TYPE, FILE_ROW_NUM)
FROM (
    SELECT
        $1,$2,$3,$4,$5,$6,$7,
        METADATA$FILENAME,
        'INDIA',
        'DATA',
        METADATA$FILE_ROW_NUMBER
    FROM @SKYPOINTS_DB.RAW.STG_MEMBER_INDIA
)
FILE_FORMAT = (FORMAT_NAME = SKYPOINTS_DB.RAW.FF_MEMBER_CSV)
ON_ERROR    = CONTINUE;

-- -----------------------------------------------------------
-- 3. AUS feed — 6 columns (UniqueID,MemberName,TierType,
--    DOB,EnrollDate,FlightDate) — YYYY-MM-DD dates, DOB may be NULL.
--    For XLSX files use SP_LOAD_AUS_XLSX instead of this block.
--    This COPY INTO handles CSV exports of the same layout.
-- -----------------------------------------------------------
COPY INTO SKYPOINTS_DB.RAW.MEMBER_LOAD
    (COL_01,COL_02,COL_03,COL_04,COL_05,COL_06,
     SOURCE_FILE, SOURCE_FORMAT, RECORD_TYPE, FILE_ROW_NUM)
FROM (
    SELECT
        $1,$2,$3,$4,$5,$6,
        METADATA$FILENAME,
        'AUS',
        'DATA',
        METADATA$FILE_ROW_NUMBER
    FROM @SKYPOINTS_DB.RAW.STG_MEMBER_AUS
)
FILE_FORMAT = (FORMAT_NAME = SKYPOINTS_DB.RAW.FF_MEMBER_CSV)
ON_ERROR    = CONTINUE;

-- -----------------------------------------------------------
-- 4. USA feed — 5 columns (ID,Name,TierCode,
--    EnrollDate,FlightDate) — unpadded MMDDYYYY dates, no DOB
-- -----------------------------------------------------------
COPY INTO SKYPOINTS_DB.RAW.MEMBER_LOAD
    (COL_01,COL_02,COL_03,COL_04,COL_05,
     SOURCE_FILE, SOURCE_FORMAT, RECORD_TYPE, FILE_ROW_NUM)
FROM (
    SELECT
        $1,$2,$3,$4,$5,
        METADATA$FILENAME,
        'USA',
        'DATA',
        METADATA$FILE_ROW_NUMBER
    FROM @SKYPOINTS_DB.RAW.STG_MEMBER_USA
)
FILE_FORMAT = (FORMAT_NAME = SKYPOINTS_DB.RAW.FF_MEMBER_CSV)
ON_ERROR    = CONTINUE;

-- -----------------------------------------------------------
-- 5. NDJSON redemptions feed — entire object as VARIANT
-- -----------------------------------------------------------
COPY INTO SKYPOINTS_DB.RAW.REDEMPTIONS_RAW
    (RAW_RECORD, SOURCE_FILE, FILE_ROW_NUM)
FROM (
    SELECT
        $1,
        METADATA$FILENAME,
        METADATA$FILE_ROW_NUMBER
    FROM @SKYPOINTS_DB.RAW.STG_REDEMPTIONS
)
FILE_FORMAT = (FORMAT_NAME = SKYPOINTS_DB.RAW.FF_REDEMPTIONS_JSON)
ON_ERROR    = CONTINUE;
