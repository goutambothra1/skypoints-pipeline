
-- Design decisions:
--   COUNTRY_MAP drives which CORE table a member is routed to.
--   It maps every observed source code (IND, IN, USA, US, AU, AUS …)
--   to both a canonical ISO-3 code and a target table name.
--   Using MERGE to seed ensures re-runs do not create duplicates.
-- =============================================================

USE DATABASE SKYPOINTS_DB;
USE SCHEMA    CORE;
USE WAREHOUSE WH_SKYPOINTS;

CREATE TABLE IF NOT EXISTS SKYPOINTS_DB.CORE.COUNTRY_MAP (
    COUNTRY_CODE    VARCHAR(10)     NOT NULL,   -- Source code as seen in member record
    COUNTRY_NAME    VARCHAR(100),
    ISO3_CODE       VARCHAR(3),                 -- Canonical 3-letter ISO code
    TABLE_NAME      VARCHAR(100)    NOT NULL,   -- Target CORE table (e.g. TABLE_INDIA)
    SOURCE_FORMAT   VARCHAR(50),                -- Expected feed format for this country
    IS_ACTIVE       BOOLEAN         DEFAULT TRUE,
    CREATED_TS      TIMESTAMP_NTZ   DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT PK_COUNTRY_MAP PRIMARY KEY (COUNTRY_CODE)
)
COMMENT = 'Reference table: maps every observed country code to a CORE target table';

-- Idempotent seed via MERGE (insert new codes, update existing)
MERGE INTO SKYPOINTS_DB.CORE.COUNTRY_MAP AS tgt
USING (
    SELECT *
    FROM VALUES
        ('IND',  'India',           'IND', 'TABLE_INDIA',  'INDIA',    TRUE),
        ('IN',   'India',           'IND', 'TABLE_INDIA',  'INDIA',    TRUE),
        ('USA',  'United States',   'USA', 'TABLE_USA',    'USA',      TRUE),
        ('US',   'United States',   'USA', 'TABLE_USA',    'USA',      TRUE),
        ('CAN',  'Canada',          'CAN', 'TABLE_CANADA', 'CANADA',   TRUE),
        ('CA',   'Canada',          'CAN', 'TABLE_CANADA', 'CANADA',   TRUE),
        ('AUS',  'Australia',       'AUS', 'TABLE_OTHER',  'ORIGINAL', TRUE),
        ('AU',   'Australia',       'AUS', 'TABLE_OTHER',  'ORIGINAL', TRUE),
        ('PHL',  'Philippines',     'PHL', 'TABLE_OTHER',  'ORIGINAL', TRUE),
        ('PHIL', 'Philippines',     'PHL', 'TABLE_OTHER',  'ORIGINAL', TRUE)
    AS t(COUNTRY_CODE, COUNTRY_NAME, ISO3_CODE, TABLE_NAME, SOURCE_FORMAT, IS_ACTIVE)
) AS src
ON tgt.COUNTRY_CODE = src.COUNTRY_CODE
WHEN MATCHED THEN UPDATE SET
    tgt.COUNTRY_NAME   = src.COUNTRY_NAME,
    tgt.ISO3_CODE      = src.ISO3_CODE,
    tgt.TABLE_NAME     = src.TABLE_NAME,
    tgt.SOURCE_FORMAT  = src.SOURCE_FORMAT,
    tgt.IS_ACTIVE      = src.IS_ACTIVE
WHEN NOT MATCHED THEN INSERT
    (COUNTRY_CODE, COUNTRY_NAME, ISO3_CODE, TABLE_NAME, SOURCE_FORMAT, IS_ACTIVE)
VALUES
    (src.COUNTRY_CODE, src.COUNTRY_NAME, src.ISO3_CODE,
     src.TABLE_NAME,   src.SOURCE_FORMAT, src.IS_ACTIVE);
