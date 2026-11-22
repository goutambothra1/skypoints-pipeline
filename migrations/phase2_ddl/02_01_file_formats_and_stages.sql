

USE DATABASE SKYPOINTS_DB;
USE WAREHOUSE WH_SKYPOINTS;

-- -----------------------------------------------------------
-- FILE FORMATS
-- -----------------------------------------------------------

-- Original member feed: pipe-delimited, H/D record-type rows.
-- SKIP_HEADER = 0: we load ALL rows (H and D) and filter in SQL,
-- because COPY INTO cannot conditionally skip non-numeric header rows.
-- NULL_IF handles both literal 'NULL' strings and empty fields.
CREATE FILE FORMAT IF NOT EXISTS SKYPOINTS_DB.RAW.FF_MEMBER_PIPE
    TYPE                    = 'CSV'
    FIELD_DELIMITER         = '|'
    RECORD_DELIMITER        = '\n'
    SKIP_HEADER             = 0
    NULL_IF                 = ('NULL', 'null', '')
    EMPTY_FIELD_AS_NULL     = TRUE
    TRIM_SPACE              = TRUE
    COMMENT                 = 'Pipe-delimited member feed — H header rows, D detail rows';

-- India / USA / Canada CSV feeds: comma-delimited, one header row to skip.
-- SKIP_HEADER = 1 removes the column-name row before COPY INTO.
CREATE FILE FORMAT IF NOT EXISTS SKYPOINTS_DB.RAW.FF_MEMBER_CSV
    TYPE                    = 'CSV'
    FIELD_DELIMITER         = ','
    RECORD_DELIMITER        = '\n'
    SKIP_HEADER             = 1
    NULL_IF                 = ('NULL', 'null', 'N/A', '')
    EMPTY_FIELD_AS_NULL     = TRUE
    TRIM_SPACE              = TRUE
    COMMENT                 = 'CSV member feed for India / USA / Canada — one header row';

-- Redemptions: NDJSON — one JSON object per line (no outer array).
-- STRIP_OUTER_ARRAY = FALSE because there is no wrapping [].
CREATE FILE FORMAT IF NOT EXISTS SKYPOINTS_DB.RAW.FF_REDEMPTIONS_JSON
    TYPE                    = 'JSON'
    STRIP_OUTER_ARRAY       = FALSE
    COMMENT                 = 'NDJSON redemptions feed — one JSON object per line';

-- -----------------------------------------------------------
-- INTERNAL STAGES (one per source feed)
-- Keeping stages separate gives independent COPY INTO history,
-- so re-loading one feed never affects another feed's load log.
-- -----------------------------------------------------------

CREATE STAGE IF NOT EXISTS SKYPOINTS_DB.RAW.STG_MEMBER_ORIGINAL
    FILE_FORMAT             = SKYPOINTS_DB.RAW.FF_MEMBER_PIPE
    COMMENT                 = 'Original pipe-delimited member feed (H/D rows)';

CREATE STAGE IF NOT EXISTS SKYPOINTS_DB.RAW.STG_MEMBER_INDIA
    FILE_FORMAT             = SKYPOINTS_DB.RAW.FF_MEMBER_CSV
    COMMENT                 = 'India member feed (M/D/YYYY dates, Individual flag)';

CREATE STAGE IF NOT EXISTS SKYPOINTS_DB.RAW.STG_MEMBER_USA
    FILE_FORMAT             = SKYPOINTS_DB.RAW.FF_MEMBER_CSV
    COMMENT                 = 'USA member feed (YYYY-MM-DD dates, possible NULL strings, invalid dates)';

CREATE STAGE IF NOT EXISTS SKYPOINTS_DB.RAW.STG_MEMBER_CANADA
    FILE_FORMAT             = SKYPOINTS_DB.RAW.FF_MEMBER_CSV
    COMMENT                 = 'Canada member feed (unpadded MMDDYYYY dates, e.g. 6152022)';

CREATE STAGE IF NOT EXISTS SKYPOINTS_DB.RAW.STG_REDEMPTIONS
    FILE_FORMAT             = SKYPOINTS_DB.RAW.FF_REDEMPTIONS_JSON
    COMMENT                 = 'NDJSON redemptions feed';
