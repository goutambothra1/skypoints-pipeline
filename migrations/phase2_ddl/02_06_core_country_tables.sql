
-- Design decisions:
--   1. All four tables share an identical column schema so that
--      V_ALL_MEMBERS (Phase 7) can UNION ALL them without casting.
--   2. MEMBER_SK is an IDENTITY surrogate key; MEMBER_ID is the
--      natural key with a UNIQUE constraint.
--   3. TABLE_OTHER acts as a catch-all for any country code not
--      yet assigned its own table (AU/AUS, PHIL/PHL today).
--   4. DW_UPDATE_TS is set by the MERGE in SP_LOAD_CORE_MEMBERS
--      (Phase 6) whenever an existing row is updated.
-- =============================================================

USE DATABASE SKYPOINTS_DB;
USE SCHEMA    CORE;
USE WAREHOUSE WH_SKYPOINTS;

-- Macro-equivalent: same DDL, four table names
-- TABLE_INDIA
CREATE TABLE IF NOT EXISTS SKYPOINTS_DB.CORE.TABLE_INDIA (
    MEMBER_SK           NUMBER          AUTOINCREMENT PRIMARY KEY,
    MEMBER_ID           VARCHAR(18)     NOT NULL UNIQUE,
    MEMBER_NAME         VARCHAR(200),
    ENROLLMENT_DATE     DATE,
    LAST_FLIGHT_DATE    DATE,
    TIER_CODE           VARCHAR(10),
    AGENT_NAME          VARCHAR(200),
    STATE               VARCHAR(100),
    COUNTRY             VARCHAR(10),
    DOB                 DATE,
    IS_ACTIVE           BOOLEAN,
    MEMBER_TYPE         VARCHAR(1),
    AGE                 NUMBER,
    STALE_MEMBER        VARCHAR(1),
    SOURCE_FILE         VARCHAR(500),
    LOAD_TS             TIMESTAMP_NTZ,
    DW_INSERT_TS        TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    DW_UPDATE_TS        TIMESTAMP_NTZ
)
COMMENT = 'CORE dimension: India members (SCD-1 latest-wins MERGE)';

-- TABLE_USA
CREATE TABLE IF NOT EXISTS SKYPOINTS_DB.CORE.TABLE_USA (
    MEMBER_SK           NUMBER          AUTOINCREMENT PRIMARY KEY,
    MEMBER_ID           VARCHAR(18)     NOT NULL UNIQUE,
    MEMBER_NAME         VARCHAR(200),
    ENROLLMENT_DATE     DATE,
    LAST_FLIGHT_DATE    DATE,
    TIER_CODE           VARCHAR(10),
    AGENT_NAME          VARCHAR(200),
    STATE               VARCHAR(100),
    COUNTRY             VARCHAR(10),
    DOB                 DATE,
    IS_ACTIVE           BOOLEAN,
    MEMBER_TYPE         VARCHAR(1),
    AGE                 NUMBER,
    STALE_MEMBER        VARCHAR(1),
    SOURCE_FILE         VARCHAR(500),
    LOAD_TS             TIMESTAMP_NTZ,
    DW_INSERT_TS        TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    DW_UPDATE_TS        TIMESTAMP_NTZ
)
COMMENT = 'CORE dimension: USA members (SCD-1 latest-wins MERGE)';

-- TABLE_CANADA
CREATE TABLE IF NOT EXISTS SKYPOINTS_DB.CORE.TABLE_CANADA (
    MEMBER_SK           NUMBER          AUTOINCREMENT PRIMARY KEY,
    MEMBER_ID           VARCHAR(18)     NOT NULL UNIQUE,
    MEMBER_NAME         VARCHAR(200),
    ENROLLMENT_DATE     DATE,
    LAST_FLIGHT_DATE    DATE,
    TIER_CODE           VARCHAR(10),
    AGENT_NAME          VARCHAR(200),
    STATE               VARCHAR(100),
    COUNTRY             VARCHAR(10),
    DOB                 DATE,
    IS_ACTIVE           BOOLEAN,
    MEMBER_TYPE         VARCHAR(1),
    AGE                 NUMBER,
    STALE_MEMBER        VARCHAR(1),
    SOURCE_FILE         VARCHAR(500),
    LOAD_TS             TIMESTAMP_NTZ,
    DW_INSERT_TS        TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    DW_UPDATE_TS        TIMESTAMP_NTZ
)
COMMENT = 'CORE dimension: Canada members (SCD-1 latest-wins MERGE)';

-- TABLE_OTHER — catch-all for AU/AUS, PHL/PHIL, and future countries
CREATE TABLE IF NOT EXISTS SKYPOINTS_DB.CORE.TABLE_OTHER (
    MEMBER_SK           NUMBER          AUTOINCREMENT PRIMARY KEY,
    MEMBER_ID           VARCHAR(18)     NOT NULL UNIQUE,
    MEMBER_NAME         VARCHAR(200),
    ENROLLMENT_DATE     DATE,
    LAST_FLIGHT_DATE    DATE,
    TIER_CODE           VARCHAR(10),
    AGENT_NAME          VARCHAR(200),
    STATE               VARCHAR(100),
    COUNTRY             VARCHAR(10),
    DOB                 DATE,
    IS_ACTIVE           BOOLEAN,
    MEMBER_TYPE         VARCHAR(1),
    AGE                 NUMBER,
    STALE_MEMBER        VARCHAR(1),
    SOURCE_FILE         VARCHAR(500),
    LOAD_TS             TIMESTAMP_NTZ,
    DW_INSERT_TS        TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    DW_UPDATE_TS        TIMESTAMP_NTZ
)
COMMENT = 'CORE dimension: catch-all for AU, PHL and future countries';
