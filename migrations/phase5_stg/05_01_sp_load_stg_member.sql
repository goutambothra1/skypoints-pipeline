-- =============================================================
-- SkyPoints Loyalty Pipeline
-- Phase 5 — SP_LOAD_STG_MEMBER
-- Idempotent: MERGE on MEMBER_ID; re-run is safe.
-- =============================================================
-- Column layout per SOURCE_FORMAT (positions in RAW.MEMBER_LOAD):
--   ORIGINAL  COL_04=Member_Id  COL_03=Name  COL_05=EnrollDate(YYYYMMDD)
--             COL_06=FlightDate(YYYYMMDD)   COL_07=TierCode
--             COL_08=AgentName  COL_09=State  COL_10=Country
--             COL_11=DOB(MMDDYYYY after LPAD)  COL_12=IsActive
--   INDIA     COL_01=ID  COL_02=Name  COL_03=DOB(M/D/YYYY)
--             COL_04=TierCode  COL_05=EnrollDate(M/D/YYYY)
--             COL_06=Individual  COL_07=FlightDate(M/D/YYYY)
--   AUS       COL_01=UniqueID  COL_02=Name  COL_03=TierType
--             COL_04=DOB(YYYY-MM-DD or 'NULL')
--             COL_05=EnrollDate(YYYY-MM-DD)  COL_06=FlightDate
--   USA       COL_01=ID  COL_02=Name  COL_03=TierCode
--             COL_04=EnrollDate(unpadded MMDDYYYY)
--             COL_05=FlightDate(unpadded MMDDYYYY)
--
-- Reject criterion: MEMBER_ID IS NULL or empty string.
-- All other issues (bad dates, invalid tier, etc.) stay in STG
-- with DQ_STATUS = 'WARN' and a pipe-separated DQ_REASON list.
--
-- Dedup: QUALIFY ROW_NUMBER() OVER (PARTITION BY MEMBER_ID
--        ORDER BY LOAD_TS DESC, FILE_ROW_NUM DESC) = 1
--   → latest-loaded record wins within the batch.
--   The MERGE also updates existing STG rows when a newer record
--   arrives (e.g., country-moved member reloaded from new feed).
--
-- AGE: birthday-aware (subtracts 1 if birthday not yet reached
--      this calendar year).
-- STALE_MEMBER: 'Y' when LAST_FLIGHT_DATE IS NULL (conservative
--   assumption — no recorded flight = treat as stale) or when
--   DATEDIFF('day', LAST_FLIGHT_DATE, CURRENT_DATE()) > 90.
-- =============================================================

USE DATABASE SKYPOINTS_DB;
USE WAREHOUSE WH_SKYPOINTS;

CREATE OR REPLACE PROCEDURE SKYPOINTS_DB.STG.SP_LOAD_STG_MEMBER()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN

    -- -------------------------------------------------------
    -- STEP 1: Route rows with no usable MEMBER_ID to REJECTS
    -- -------------------------------------------------------
    INSERT INTO SKYPOINTS_DB.STG.MEMBER_REJECT (
        RAW_MEMBER_ID, RAW_MEMBER_NAME,
        RAW_ENROLLMENT_DATE, RAW_LAST_FLIGHT_DATE,
        RAW_TIER_CODE, RAW_AGENT_NAME, RAW_STATE,
        RAW_COUNTRY, RAW_DOB, RAW_IS_ACTIVE, RAW_MEMBER_TYPE,
        SOURCE_FORMAT, SOURCE_FILE, LOAD_TS, FILE_ROW_NUM,
        REJECT_REASON, REJECT_TS
    )
    SELECT
        CASE SOURCE_FORMAT
            WHEN 'ORIGINAL' THEN COL_04
            ELSE COL_01
        END                             AS RAW_MEMBER_ID,
        CASE SOURCE_FORMAT
            WHEN 'ORIGINAL' THEN COL_03
            ELSE COL_02
        END                             AS RAW_MEMBER_NAME,
        CASE SOURCE_FORMAT
            WHEN 'ORIGINAL' THEN COL_05
            WHEN 'INDIA'    THEN COL_05
            WHEN 'AUS'      THEN COL_05
            WHEN 'USA'      THEN COL_04
        END                             AS RAW_ENROLLMENT_DATE,
        CASE SOURCE_FORMAT
            WHEN 'ORIGINAL' THEN COL_06
            WHEN 'INDIA'    THEN COL_07
            WHEN 'AUS'      THEN COL_06
            WHEN 'USA'      THEN COL_05
        END                             AS RAW_LAST_FLIGHT_DATE,
        CASE SOURCE_FORMAT
            WHEN 'ORIGINAL' THEN COL_07
            WHEN 'INDIA'    THEN COL_04
            ELSE COL_03
        END                             AS RAW_TIER_CODE,
        CASE SOURCE_FORMAT WHEN 'ORIGINAL' THEN COL_08 ELSE NULL END AS RAW_AGENT_NAME,
        CASE SOURCE_FORMAT WHEN 'ORIGINAL' THEN COL_09 ELSE NULL END AS RAW_STATE,
        CASE SOURCE_FORMAT
            WHEN 'ORIGINAL' THEN COL_10
            WHEN 'INDIA'    THEN 'IND'
            WHEN 'AUS'      THEN 'AUS'
            WHEN 'USA'      THEN 'USA'
        END                             AS RAW_COUNTRY,
        CASE SOURCE_FORMAT
            WHEN 'ORIGINAL' THEN COL_11
            WHEN 'INDIA'    THEN COL_03
            WHEN 'AUS'      THEN COL_04
            ELSE NULL
        END                             AS RAW_DOB,
        CASE SOURCE_FORMAT WHEN 'ORIGINAL' THEN COL_12 ELSE NULL END AS RAW_IS_ACTIVE,
        CASE SOURCE_FORMAT WHEN 'INDIA' THEN COL_06 ELSE NULL END    AS RAW_MEMBER_TYPE,
        SOURCE_FORMAT, SOURCE_FILE, LOAD_TS, FILE_ROW_NUM,
        'NULL_OR_EMPTY_MEMBER_ID',
        CURRENT_TIMESTAMP()
    FROM SKYPOINTS_DB.RAW.MEMBER_LOAD
    WHERE RECORD_TYPE IN ('D', 'DATA')
      AND (
            CASE SOURCE_FORMAT
                WHEN 'ORIGINAL' THEN NULLIF(TRIM(COL_04), '')
                ELSE NULLIF(TRIM(COL_01), '')
            END
          ) IS NULL;

    -- -------------------------------------------------------
    -- STEP 2: MERGE clean rows into STG.MEMBER
    --         (deduped within batch; latest LOAD_TS wins)
    -- -------------------------------------------------------
    MERGE INTO SKYPOINTS_DB.STG.MEMBER AS tgt
    USING (

        WITH mapped AS (
            SELECT
                -- Natural key
                CASE SOURCE_FORMAT
                    WHEN 'ORIGINAL' THEN TRIM(COL_04)
                    ELSE TRIM(COL_01)
                END                                                     AS MEMBER_ID,

                CASE SOURCE_FORMAT
                    WHEN 'ORIGINAL' THEN NULLIF(TRIM(COL_03), '')
                    ELSE NULLIF(TRIM(COL_02), '')
                END                                                     AS MEMBER_NAME,

                -- Parsed ENROLLMENT_DATE per format
                CASE SOURCE_FORMAT
                    WHEN 'ORIGINAL' THEN TRY_TO_DATE(COL_05, 'YYYYMMDD')
                    WHEN 'INDIA'    THEN TRY_TO_DATE(COL_05, 'MM/DD/YYYY')
                    WHEN 'AUS'      THEN TRY_TO_DATE(SUBSTR(NULLIF(COL_05,'NULL'),1,10),'YYYY-MM-DD')
                    WHEN 'USA'      THEN TRY_TO_DATE(LPAD(COL_04, 8, '0'), 'MMDDYYYY')
                END                                                     AS ENROLLMENT_DATE,

                -- Raw enrollment (for DQ check)
                CASE SOURCE_FORMAT
                    WHEN 'ORIGINAL' THEN COL_05
                    WHEN 'INDIA'    THEN COL_05
                    WHEN 'AUS'      THEN COL_05
                    WHEN 'USA'      THEN COL_04
                END                                                     AS RAW_ENROLL,

                -- Parsed LAST_FLIGHT_DATE per format
                CASE SOURCE_FORMAT
                    WHEN 'ORIGINAL' THEN TRY_TO_DATE(COL_06, 'YYYYMMDD')
                    WHEN 'INDIA'    THEN TRY_TO_DATE(COL_07, 'MM/DD/YYYY')
                    WHEN 'AUS'      THEN TRY_TO_DATE(SUBSTR(NULLIF(COL_06,'NULL'),1,10),'YYYY-MM-DD')
                    WHEN 'USA'      THEN TRY_TO_DATE(LPAD(COL_05, 8, '0'), 'MMDDYYYY')
                END                                                     AS LAST_FLIGHT_DATE,

                -- Raw flight date (for DQ check)
                CASE SOURCE_FORMAT
                    WHEN 'ORIGINAL' THEN COL_06
                    WHEN 'INDIA'    THEN COL_07
                    WHEN 'AUS'      THEN COL_06
                    WHEN 'USA'      THEN COL_05
                END                                                     AS RAW_FLIGHT,

                UPPER(TRIM(CASE SOURCE_FORMAT
                    WHEN 'ORIGINAL' THEN COL_07
                    WHEN 'INDIA'    THEN COL_04
                    ELSE COL_03
                END))                                                   AS TIER_CODE,

                CASE SOURCE_FORMAT WHEN 'ORIGINAL' THEN NULLIF(TRIM(COL_08),'') ELSE NULL END AS AGENT_NAME,
                CASE SOURCE_FORMAT WHEN 'ORIGINAL' THEN NULLIF(TRIM(COL_09),'') ELSE NULL END AS STATE,

                -- Raw country (to be normalised via COUNTRY_MAP)
                CASE SOURCE_FORMAT
                    WHEN 'ORIGINAL' THEN UPPER(TRIM(COL_10))
                    WHEN 'INDIA'    THEN 'IND'
                    WHEN 'AUS'      THEN 'AUS'
                    WHEN 'USA'      THEN 'USA'
                END                                                     AS COUNTRY_RAW,

                -- Raw DOB (for DQ check)
                CASE SOURCE_FORMAT
                    WHEN 'ORIGINAL' THEN COL_11
                    WHEN 'INDIA'    THEN COL_03
                    WHEN 'AUS'      THEN COL_04
                    ELSE NULL
                END                                                     AS RAW_DOB,

                -- Parsed DOB per format
                -- ORIGINAL: MMDDYYYY — LPAD to 8 chars first to restore missing leading zero
                -- INDIA:    M/D/YYYY
                -- AUS:      YYYY-MM-DD (literal 'NULL' string already NULL via NULL_IF in FF)
                -- USA:      no DOB column → NULL
                CASE SOURCE_FORMAT
                    WHEN 'ORIGINAL' THEN TRY_TO_DATE(LPAD(COL_11, 8, '0'), 'MMDDYYYY')
                    WHEN 'INDIA'    THEN TRY_TO_DATE(COL_03, 'MM/DD/YYYY')
                    WHEN 'AUS'      THEN TRY_TO_DATE(SUBSTR(NULLIF(COL_04,'NULL'),1,10),'YYYY-MM-DD')
                    ELSE NULL
                END                                                     AS DOB,

                CASE SOURCE_FORMAT WHEN 'ORIGINAL' THEN (COL_12 = 'A') ELSE NULL END AS IS_ACTIVE,
                CASE SOURCE_FORMAT WHEN 'INDIA' THEN NULLIF(UPPER(TRIM(COL_06)),'') ELSE NULL END AS MEMBER_TYPE,

                SOURCE_FORMAT, SOURCE_FILE, LOAD_TS, FILE_ROW_NUM
            FROM SKYPOINTS_DB.RAW.MEMBER_LOAD
            WHERE RECORD_TYPE IN ('D', 'DATA')
              AND NULLIF(TRIM(CASE SOURCE_FORMAT
                                  WHEN 'ORIGINAL' THEN COL_04
                                  ELSE COL_01
                              END), '') IS NOT NULL
        ),

        normalised AS (
            SELECT
                m.*,
                COALESCE(cm.ISO3_CODE, m.COUNTRY_RAW) AS COUNTRY
            FROM mapped m
            LEFT JOIN SKYPOINTS_DB.CORE.COUNTRY_MAP cm ON cm.COUNTRY_CODE = m.COUNTRY_RAW
        ),

        -- Dedup: latest-loaded record wins per MEMBER_ID
        deduped AS (
            SELECT *
            FROM normalised
            QUALIFY ROW_NUMBER() OVER (
                PARTITION BY MEMBER_ID
                ORDER BY LOAD_TS DESC, FILE_ROW_NUM DESC
            ) = 1
        ),

        with_derived AS (
            SELECT
                d.*,

                -- Birthday-aware AGE
                CASE WHEN DOB IS NOT NULL THEN
                    DATEDIFF('year', DOB, CURRENT_DATE())
                    - IFF(CURRENT_DATE() <
                          DATEADD('year', DATEDIFF('year', DOB, CURRENT_DATE()), DOB),
                          1, 0)
                ELSE NULL END                                           AS AGE,

                -- STALE_MEMBER: NULL flight_date → conservative 'Y'
                CASE
                    WHEN LAST_FLIGHT_DATE IS NULL THEN 'Y'
                    WHEN DATEDIFF('day', LAST_FLIGHT_DATE, CURRENT_DATE()) > 90 THEN 'Y'
                    ELSE 'N'
                END                                                     AS STALE_MEMBER,

                -- DQ_REASON: pipe-separated list of failed rule codes
                TRIM(BOTH '|' FROM
                    CASE WHEN ENROLLMENT_DATE  IS NULL AND RAW_ENROLL  IS NOT NULL
                         THEN '|INVALID_ENROLL_DATE'    ELSE '' END ||
                    CASE WHEN LAST_FLIGHT_DATE IS NULL AND RAW_FLIGHT  IS NOT NULL
                         THEN '|INVALID_FLIGHT_DATE'    ELSE '' END ||
                    CASE WHEN DOB              IS NULL AND RAW_DOB     IS NOT NULL
                         THEN '|INVALID_DOB'            ELSE '' END ||
                    CASE WHEN TIER_CODE NOT IN ('PLT','GLD','SLV')
                         THEN '|INVALID_TIER_CODE'      ELSE '' END ||
                    CASE WHEN DOB IS NOT NULL AND DOB > CURRENT_DATE()
                         THEN '|FUTURE_DOB'             ELSE '' END ||
                    CASE WHEN ENROLLMENT_DATE IS NOT NULL
                              AND LAST_FLIGHT_DATE IS NOT NULL
                              AND LAST_FLIGHT_DATE < ENROLLMENT_DATE
                         THEN '|FLIGHT_BEFORE_ENROLL'   ELSE '' END
                )                                                       AS DQ_REASON
            FROM deduped d
        )

        SELECT
            MEMBER_ID, MEMBER_NAME, ENROLLMENT_DATE, LAST_FLIGHT_DATE,
            TIER_CODE, AGENT_NAME, STATE, COUNTRY, DOB, IS_ACTIVE,
            MEMBER_TYPE, AGE, STALE_MEMBER, SOURCE_FORMAT, SOURCE_FILE,
            LOAD_TS, FILE_ROW_NUM,
            CASE WHEN DQ_REASON = '' THEN 'PASS' ELSE 'WARN' END AS DQ_STATUS,
            NULLIF(DQ_REASON, '')                                  AS DQ_REASON
        FROM with_derived

    ) AS src ON tgt.MEMBER_ID = src.MEMBER_ID

    WHEN MATCHED THEN UPDATE SET
        tgt.MEMBER_NAME         = src.MEMBER_NAME,
        tgt.ENROLLMENT_DATE     = src.ENROLLMENT_DATE,
        tgt.LAST_FLIGHT_DATE    = src.LAST_FLIGHT_DATE,
        tgt.TIER_CODE           = src.TIER_CODE,
        tgt.AGENT_NAME          = src.AGENT_NAME,
        tgt.STATE               = src.STATE,
        tgt.COUNTRY             = src.COUNTRY,
        tgt.DOB                 = src.DOB,
        tgt.IS_ACTIVE           = src.IS_ACTIVE,
        tgt.MEMBER_TYPE         = src.MEMBER_TYPE,
        tgt.AGE                 = src.AGE,
        tgt.STALE_MEMBER        = src.STALE_MEMBER,
        tgt.SOURCE_FORMAT       = src.SOURCE_FORMAT,
        tgt.SOURCE_FILE         = src.SOURCE_FILE,
        tgt.LOAD_TS             = src.LOAD_TS,
        tgt.FILE_ROW_NUM        = src.FILE_ROW_NUM,
        tgt.DQ_STATUS           = src.DQ_STATUS,
        tgt.DQ_REASON           = src.DQ_REASON,
        tgt.DW_UPDATE_TS        = CURRENT_TIMESTAMP()

    WHEN NOT MATCHED THEN INSERT (
        MEMBER_ID, MEMBER_NAME, ENROLLMENT_DATE, LAST_FLIGHT_DATE,
        TIER_CODE, AGENT_NAME, STATE, COUNTRY, DOB, IS_ACTIVE,
        MEMBER_TYPE, AGE, STALE_MEMBER, SOURCE_FORMAT, SOURCE_FILE,
        LOAD_TS, FILE_ROW_NUM, DQ_STATUS, DQ_REASON, DW_INSERT_TS
    ) VALUES (
        src.MEMBER_ID, src.MEMBER_NAME, src.ENROLLMENT_DATE, src.LAST_FLIGHT_DATE,
        src.TIER_CODE, src.AGENT_NAME, src.STATE, src.COUNTRY, src.DOB, src.IS_ACTIVE,
        src.MEMBER_TYPE, src.AGE, src.STALE_MEMBER, src.SOURCE_FORMAT, src.SOURCE_FILE,
        src.LOAD_TS, src.FILE_ROW_NUM, src.DQ_STATUS, src.DQ_REASON, CURRENT_TIMESTAMP()
    );

    RETURN 'SP_LOAD_STG_MEMBER complete';
END;
$$;
