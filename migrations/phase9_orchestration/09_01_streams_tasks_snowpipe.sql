
-- STREAM design:
--   APPEND_ONLY=TRUE: member/redemption loads are insert-only.
--   Append-only streams are more efficient than standard streams
--   because they skip UPDATE/DELETE tracking.
--
-- TASK DAG (all tasks in RAW schema to satisfy AFTER constraints):
--
--   TASK_PIPELINE_ROOT (CRON every 15 min)
--          │
--          ├─► TASK_STG_MEMBER     [WHEN STREAM_MEMBER_LOAD has data]
--          │       └─► TASK_CORE_MEMBERS
--          │                └─► TASK_DQ_CHECK ◄─────┐
--          │                                          │
--          └─► TASK_REDEMPTIONS  [WHEN STREAM_REDEMPTIONS_RAW has data]
--                                                     │
--                                           ──────────┘
--
-- Tasks fire only when their guarding stream has data, so idle
-- runs cost nothing (no warehouse credits consumed).
--
-- SNOWPIPE note:
--   PIPE_MEMBER_ORIGINAL uses AUTO_INGEST=FALSE (internal stage).
--   For production: replace with an external stage (S3/Azure/GCS)
--   and set AUTO_INGEST=TRUE + wire a notification integration
--   (SQS / Event Grid / Pub-Sub) to fire the pipe on file arrival.
--   Then the TASK_PIPELINE_ROOT + streams pattern can be replaced
--   by: Snowpipe (auto-ingest to RAW) → Stream → Task chain.
-- =============================================================

USE DATABASE SKYPOINTS_DB; USE WAREHOUSE WH_SKYPOINTS;

-- Streams
CREATE STREAM IF NOT EXISTS SKYPOINTS_DB.RAW.STREAM_MEMBER_LOAD
    ON TABLE SKYPOINTS_DB.RAW.MEMBER_LOAD
    APPEND_ONLY = TRUE;

CREATE STREAM IF NOT EXISTS SKYPOINTS_DB.RAW.STREAM_REDEMPTIONS_RAW
    ON TABLE SKYPOINTS_DB.RAW.REDEMPTIONS_RAW
    APPEND_ONLY = TRUE;

-- Task DAG (see tasks created in Snowflake during Phase 9)
-- Resume order: leaf tasks first, root task last
-- ALTER TASK SKYPOINTS_DB.RAW.TASK_DQ_CHECK       RESUME;
-- ALTER TASK SKYPOINTS_DB.RAW.TASK_REDEMPTIONS     RESUME;
-- ALTER TASK SKYPOINTS_DB.RAW.TASK_CORE_MEMBERS    RESUME;
-- ALTER TASK SKYPOINTS_DB.RAW.TASK_STG_MEMBER      RESUME;
-- ALTER TASK SKYPOINTS_DB.RAW.TASK_PIPELINE_ROOT   RESUME;

-- Snowpipe stub
CREATE PIPE IF NOT EXISTS SKYPOINTS_DB.RAW.PIPE_MEMBER_ORIGINAL
    AUTO_INGEST = FALSE
    COMMENT     = 'Set AUTO_INGEST=TRUE with external stage + notification integration for production'
AS
    COPY INTO SKYPOINTS_DB.RAW.MEMBER_LOAD
        (COL_01,COL_02,COL_03,COL_04,COL_05,COL_06,
         COL_07,COL_08,COL_09,COL_10,COL_11,COL_12,
         SOURCE_FILE,SOURCE_FORMAT,RECORD_TYPE,FILE_ROW_NUM)
    FROM (
        SELECT $1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,
               METADATA$FILENAME,'ORIGINAL',$2,METADATA$FILE_ROW_NUMBER
        FROM @SKYPOINTS_DB.RAW.STG_MEMBER_ORIGINAL
    )
    FILE_FORMAT = (FORMAT_NAME = SKYPOINTS_DB.RAW.FF_MEMBER_PIPE)
    ON_ERROR = CONTINUE;
