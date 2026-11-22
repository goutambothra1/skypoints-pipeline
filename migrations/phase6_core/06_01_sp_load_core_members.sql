
-- Design decisions:
--   1. Four separate MERGE statements (one per CORE table) are
--      used instead of dynamic SQL so that the query is fully
--      set-based and the optimizer can generate efficient plans.
--   2. Each MERGE sources only rows whose COUNTRY_MAP.TABLE_NAME
--      matches the target table, so only relevant rows touch each
--      partition of work.
--   3. Cross-country move: after all MERGEs, a DELETE removes a
--      member from their OLD country table when STG.MEMBER now
--      maps them to a DIFFERENT table.  Example:
--        Nora (223460) moved from CAN → USA:
--        → MERGEd into TABLE_USA ✓
--        → DELETEd from TABLE_CANADA, TABLE_OTHER, TABLE_INDIA ✓
--   4. AGE is recomputed at CORE load time so it stays current
--      even if STG was loaded days ago.
-- =============================================================

USE DATABASE SKYPOINTS_DB;
USE WAREHOUSE WH_SKYPOINTS;

CREATE OR REPLACE PROCEDURE SKYPOINTS_DB.CORE.SP_LOAD_CORE_MEMBERS()
RETURNS VARCHAR
LANGUAGE SQL
AS
$$
BEGIN

    -- -------------------------------------------------------
    -- Helper macro: columns common to all four MERGE targets
    -- -------------------------------------------------------

    -- MERGE → TABLE_INDIA
    MERGE INTO SKYPOINTS_DB.CORE.TABLE_INDIA AS tgt
    USING (
        SELECT s.*,
               -- Recompute AGE at CORE load time for freshness
               CASE WHEN s.DOB IS NOT NULL THEN
                   DATEDIFF('year', s.DOB, CURRENT_DATE())
                   - IFF(CURRENT_DATE() < DATEADD('year', DATEDIFF('year', s.DOB, CURRENT_DATE()), s.DOB), 1, 0)
               ELSE NULL END AS AGE_FRESH
        FROM SKYPOINTS_DB.STG.MEMBER s
        JOIN SKYPOINTS_DB.CORE.COUNTRY_MAP cm ON cm.COUNTRY_CODE = s.COUNTRY
        WHERE cm.TABLE_NAME = 'TABLE_INDIA'
    ) AS src ON tgt.MEMBER_ID = src.MEMBER_ID
    WHEN MATCHED THEN UPDATE SET
        tgt.MEMBER_NAME=src.MEMBER_NAME, tgt.ENROLLMENT_DATE=src.ENROLLMENT_DATE,
        tgt.LAST_FLIGHT_DATE=src.LAST_FLIGHT_DATE, tgt.TIER_CODE=src.TIER_CODE,
        tgt.AGENT_NAME=src.AGENT_NAME, tgt.STATE=src.STATE, tgt.COUNTRY=src.COUNTRY,
        tgt.DOB=src.DOB, tgt.IS_ACTIVE=src.IS_ACTIVE, tgt.MEMBER_TYPE=src.MEMBER_TYPE,
        tgt.AGE=src.AGE_FRESH, tgt.STALE_MEMBER=src.STALE_MEMBER,
        tgt.SOURCE_FILE=src.SOURCE_FILE, tgt.LOAD_TS=src.LOAD_TS,
        tgt.DW_UPDATE_TS=CURRENT_TIMESTAMP()
    WHEN NOT MATCHED THEN INSERT (
        MEMBER_ID, MEMBER_NAME, ENROLLMENT_DATE, LAST_FLIGHT_DATE,
        TIER_CODE, AGENT_NAME, STATE, COUNTRY, DOB, IS_ACTIVE,
        MEMBER_TYPE, AGE, STALE_MEMBER, SOURCE_FILE, LOAD_TS, DW_INSERT_TS
    ) VALUES (
        src.MEMBER_ID, src.MEMBER_NAME, src.ENROLLMENT_DATE, src.LAST_FLIGHT_DATE,
        src.TIER_CODE, src.AGENT_NAME, src.STATE, src.COUNTRY, src.DOB, src.IS_ACTIVE,
        src.MEMBER_TYPE, src.AGE_FRESH, src.STALE_MEMBER, src.SOURCE_FILE,
        src.LOAD_TS, CURRENT_TIMESTAMP()
    );

    -- MERGE → TABLE_USA
    MERGE INTO SKYPOINTS_DB.CORE.TABLE_USA AS tgt
    USING (
        SELECT s.*,
               CASE WHEN s.DOB IS NOT NULL THEN
                   DATEDIFF('year', s.DOB, CURRENT_DATE())
                   - IFF(CURRENT_DATE() < DATEADD('year', DATEDIFF('year', s.DOB, CURRENT_DATE()), s.DOB), 1, 0)
               ELSE NULL END AS AGE_FRESH
        FROM SKYPOINTS_DB.STG.MEMBER s
        JOIN SKYPOINTS_DB.CORE.COUNTRY_MAP cm ON cm.COUNTRY_CODE = s.COUNTRY
        WHERE cm.TABLE_NAME = 'TABLE_USA'
    ) AS src ON tgt.MEMBER_ID = src.MEMBER_ID
    WHEN MATCHED THEN UPDATE SET
        tgt.MEMBER_NAME=src.MEMBER_NAME, tgt.ENROLLMENT_DATE=src.ENROLLMENT_DATE,
        tgt.LAST_FLIGHT_DATE=src.LAST_FLIGHT_DATE, tgt.TIER_CODE=src.TIER_CODE,
        tgt.AGENT_NAME=src.AGENT_NAME, tgt.STATE=src.STATE, tgt.COUNTRY=src.COUNTRY,
        tgt.DOB=src.DOB, tgt.IS_ACTIVE=src.IS_ACTIVE, tgt.MEMBER_TYPE=src.MEMBER_TYPE,
        tgt.AGE=src.AGE_FRESH, tgt.STALE_MEMBER=src.STALE_MEMBER,
        tgt.SOURCE_FILE=src.SOURCE_FILE, tgt.LOAD_TS=src.LOAD_TS,
        tgt.DW_UPDATE_TS=CURRENT_TIMESTAMP()
    WHEN NOT MATCHED THEN INSERT (
        MEMBER_ID, MEMBER_NAME, ENROLLMENT_DATE, LAST_FLIGHT_DATE,
        TIER_CODE, AGENT_NAME, STATE, COUNTRY, DOB, IS_ACTIVE,
        MEMBER_TYPE, AGE, STALE_MEMBER, SOURCE_FILE, LOAD_TS, DW_INSERT_TS
    ) VALUES (
        src.MEMBER_ID, src.MEMBER_NAME, src.ENROLLMENT_DATE, src.LAST_FLIGHT_DATE,
        src.TIER_CODE, src.AGENT_NAME, src.STATE, src.COUNTRY, src.DOB, src.IS_ACTIVE,
        src.MEMBER_TYPE, src.AGE_FRESH, src.STALE_MEMBER, src.SOURCE_FILE,
        src.LOAD_TS, CURRENT_TIMESTAMP()
    );

    -- MERGE → TABLE_CANADA
    MERGE INTO SKYPOINTS_DB.CORE.TABLE_CANADA AS tgt
    USING (
        SELECT s.*,
               CASE WHEN s.DOB IS NOT NULL THEN
                   DATEDIFF('year', s.DOB, CURRENT_DATE())
                   - IFF(CURRENT_DATE() < DATEADD('year', DATEDIFF('year', s.DOB, CURRENT_DATE()), s.DOB), 1, 0)
               ELSE NULL END AS AGE_FRESH
        FROM SKYPOINTS_DB.STG.MEMBER s
        JOIN SKYPOINTS_DB.CORE.COUNTRY_MAP cm ON cm.COUNTRY_CODE = s.COUNTRY
        WHERE cm.TABLE_NAME = 'TABLE_CANADA'
    ) AS src ON tgt.MEMBER_ID = src.MEMBER_ID
    WHEN MATCHED THEN UPDATE SET
        tgt.MEMBER_NAME=src.MEMBER_NAME, tgt.ENROLLMENT_DATE=src.ENROLLMENT_DATE,
        tgt.LAST_FLIGHT_DATE=src.LAST_FLIGHT_DATE, tgt.TIER_CODE=src.TIER_CODE,
        tgt.AGENT_NAME=src.AGENT_NAME, tgt.STATE=src.STATE, tgt.COUNTRY=src.COUNTRY,
        tgt.DOB=src.DOB, tgt.IS_ACTIVE=src.IS_ACTIVE, tgt.MEMBER_TYPE=src.MEMBER_TYPE,
        tgt.AGE=src.AGE_FRESH, tgt.STALE_MEMBER=src.STALE_MEMBER,
        tgt.SOURCE_FILE=src.SOURCE_FILE, tgt.LOAD_TS=src.LOAD_TS,
        tgt.DW_UPDATE_TS=CURRENT_TIMESTAMP()
    WHEN NOT MATCHED THEN INSERT (
        MEMBER_ID, MEMBER_NAME, ENROLLMENT_DATE, LAST_FLIGHT_DATE,
        TIER_CODE, AGENT_NAME, STATE, COUNTRY, DOB, IS_ACTIVE,
        MEMBER_TYPE, AGE, STALE_MEMBER, SOURCE_FILE, LOAD_TS, DW_INSERT_TS
    ) VALUES (
        src.MEMBER_ID, src.MEMBER_NAME, src.ENROLLMENT_DATE, src.LAST_FLIGHT_DATE,
        src.TIER_CODE, src.AGENT_NAME, src.STATE, src.COUNTRY, src.DOB, src.IS_ACTIVE,
        src.MEMBER_TYPE, src.AGE_FRESH, src.STALE_MEMBER, src.SOURCE_FILE,
        src.LOAD_TS, CURRENT_TIMESTAMP()
    );

    -- MERGE → TABLE_OTHER (AUS, PHL, and future catch-all)
    MERGE INTO SKYPOINTS_DB.CORE.TABLE_OTHER AS tgt
    USING (
        SELECT s.*,
               CASE WHEN s.DOB IS NOT NULL THEN
                   DATEDIFF('year', s.DOB, CURRENT_DATE())
                   - IFF(CURRENT_DATE() < DATEADD('year', DATEDIFF('year', s.DOB, CURRENT_DATE()), s.DOB), 1, 0)
               ELSE NULL END AS AGE_FRESH
        FROM SKYPOINTS_DB.STG.MEMBER s
        JOIN SKYPOINTS_DB.CORE.COUNTRY_MAP cm ON cm.COUNTRY_CODE = s.COUNTRY
        WHERE cm.TABLE_NAME = 'TABLE_OTHER'
    ) AS src ON tgt.MEMBER_ID = src.MEMBER_ID
    WHEN MATCHED THEN UPDATE SET
        tgt.MEMBER_NAME=src.MEMBER_NAME, tgt.ENROLLMENT_DATE=src.ENROLLMENT_DATE,
        tgt.LAST_FLIGHT_DATE=src.LAST_FLIGHT_DATE, tgt.TIER_CODE=src.TIER_CODE,
        tgt.AGENT_NAME=src.AGENT_NAME, tgt.STATE=src.STATE, tgt.COUNTRY=src.COUNTRY,
        tgt.DOB=src.DOB, tgt.IS_ACTIVE=src.IS_ACTIVE, tgt.MEMBER_TYPE=src.MEMBER_TYPE,
        tgt.AGE=src.AGE_FRESH, tgt.STALE_MEMBER=src.STALE_MEMBER,
        tgt.SOURCE_FILE=src.SOURCE_FILE, tgt.LOAD_TS=src.LOAD_TS,
        tgt.DW_UPDATE_TS=CURRENT_TIMESTAMP()
    WHEN NOT MATCHED THEN INSERT (
        MEMBER_ID, MEMBER_NAME, ENROLLMENT_DATE, LAST_FLIGHT_DATE,
        TIER_CODE, AGENT_NAME, STATE, COUNTRY, DOB, IS_ACTIVE,
        MEMBER_TYPE, AGE, STALE_MEMBER, SOURCE_FILE, LOAD_TS, DW_INSERT_TS
    ) VALUES (
        src.MEMBER_ID, src.MEMBER_NAME, src.ENROLLMENT_DATE, src.LAST_FLIGHT_DATE,
        src.TIER_CODE, src.AGENT_NAME, src.STATE, src.COUNTRY, src.DOB, src.IS_ACTIVE,
        src.MEMBER_TYPE, src.AGE_FRESH, src.STALE_MEMBER, src.SOURCE_FILE,
        src.LOAD_TS, CURRENT_TIMESTAMP()
    );

    -- -------------------------------------------------------
    -- Cross-country move: delete member from OLD country table
    -- when STG now maps them to a DIFFERENT table.
    -- Scenario: Nora was in TABLE_CANADA, now in TABLE_USA.
    -- -------------------------------------------------------
    DELETE FROM SKYPOINTS_DB.CORE.TABLE_INDIA
    WHERE MEMBER_ID IN (
        SELECT s.MEMBER_ID
        FROM   SKYPOINTS_DB.STG.MEMBER s
        JOIN   SKYPOINTS_DB.CORE.COUNTRY_MAP cm ON cm.COUNTRY_CODE = s.COUNTRY
        WHERE  cm.TABLE_NAME != 'TABLE_INDIA'
    );

    DELETE FROM SKYPOINTS_DB.CORE.TABLE_USA
    WHERE MEMBER_ID IN (
        SELECT s.MEMBER_ID
        FROM   SKYPOINTS_DB.STG.MEMBER s
        JOIN   SKYPOINTS_DB.CORE.COUNTRY_MAP cm ON cm.COUNTRY_CODE = s.COUNTRY
        WHERE  cm.TABLE_NAME != 'TABLE_USA'
    );

    DELETE FROM SKYPOINTS_DB.CORE.TABLE_CANADA
    WHERE MEMBER_ID IN (
        SELECT s.MEMBER_ID
        FROM   SKYPOINTS_DB.STG.MEMBER s
        JOIN   SKYPOINTS_DB.CORE.COUNTRY_MAP cm ON cm.COUNTRY_CODE = s.COUNTRY
        WHERE  cm.TABLE_NAME != 'TABLE_CANADA'
    );

    DELETE FROM SKYPOINTS_DB.CORE.TABLE_OTHER
    WHERE MEMBER_ID IN (
        SELECT s.MEMBER_ID
        FROM   SKYPOINTS_DB.STG.MEMBER s
        JOIN   SKYPOINTS_DB.CORE.COUNTRY_MAP cm ON cm.COUNTRY_CODE = s.COUNTRY
        WHERE  cm.TABLE_NAME != 'TABLE_OTHER'
    );

    RETURN 'SP_LOAD_CORE_MEMBERS complete';
END;
$$;
