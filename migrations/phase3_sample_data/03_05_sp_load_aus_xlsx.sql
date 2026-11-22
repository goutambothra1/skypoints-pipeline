-- =============================================================
-- SkyPoints Loyalty Pipeline
-- Phase 3 — SP_LOAD_AUS_XLSX
-- Snowpark Python stored procedure: loads an XLSX file from
-- STG_MEMBER_AUS directly into RAW.MEMBER_LOAD.
-- =============================================================
-- Why Snowpark Python?
--   Snowflake COPY INTO does not support .xlsx natively.
--   This proc reads the Excel bytes from the internal stage
--   using SnowflakeFile, parses them with openpyxl via pandas,
--   and inserts rows into RAW.MEMBER_LOAD — same target table
--   used by all CSV COPY INTO commands.
--
-- AUS XLSX column layout (6 columns):
--   Col 0 → COL_01 = UniqueID      (MEMBER_ID)
--   Col 1 → COL_02 = MemberName
--   Col 2 → COL_03 = TierType      (TIER_CODE)
--   Col 3 → COL_04 = DateOfBirth   (YYYY-MM-DD, may be 'NULL')
--   Col 4 → COL_05 = DateOfEnroll  (YYYY-MM-DD)
--   Col 5 → COL_06 = DateOfFlight  (YYYY-MM-DD)
--
-- Usage:
--   PUT file://path/to/AUS.xlsx @SKYPOINTS_DB.RAW.STG_MEMBER_AUS;
--   CALL SKYPOINTS_DB.RAW.SP_LOAD_AUS_XLSX(
--       '@SKYPOINTS_DB.RAW.STG_MEMBER_AUS/AUS.xlsx'
--   );
--
-- For CSV exports of the same AUS layout use COPY INTO in
-- 03_04_copy_into_raw.sql (block 3) instead.
-- =============================================================

USE DATABASE SKYPOINTS_DB;
USE WAREHOUSE WH_SKYPOINTS;

CREATE OR REPLACE PROCEDURE SKYPOINTS_DB.RAW.SP_LOAD_AUS_XLSX(FILE_PATH VARCHAR)
RETURNS VARCHAR
LANGUAGE PYTHON
RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python', 'openpyxl', 'pandas')
HANDLER = 'run'
AS $$
import io
import pandas as pd
from snowflake.snowpark.files import SnowflakeFile

def run(session, file_path: str) -> str:
    # ── 1. Read XLSX bytes from the internal Snowflake stage ──
    with SnowflakeFile.open(file_path, 'rb') as f:
        xlsx_bytes = f.read()

    # ── 2. Parse with pandas / openpyxl; treat every cell as str ──
    df = pd.read_excel(io.BytesIO(xlsx_bytes), engine='openpyxl', dtype=str)

    # Normalise: replace pandas NaN / 'nan' / empty → None
    df = df.where(df.notna(), None)
    df = df.applymap(
        lambda v: None if (v is None or str(v).strip().lower() in ('nan', '')) else str(v).strip()
    )

    if df.empty:
        return 'SP_LOAD_AUS_XLSX: no data rows found in ' + file_path

    # ── 3. Build list of dicts mapping to RAW.MEMBER_LOAD columns ──
    rows = []
    for idx, row in df.iterrows():
        def g(i):
            return row.iloc[i] if i < len(row) else None

        rows.append({
            'COL_01':        g(0),         # UniqueID   → MEMBER_ID
            'COL_02':        g(1),         # MemberName
            'COL_03':        g(2),         # TierType   → TIER_CODE
            'COL_04':        g(3),         # DateOfBirth  (YYYY-MM-DD or None)
            'COL_05':        g(4),         # DateOfEnroll (YYYY-MM-DD)
            'COL_06':        g(5),         # DateOfFlight (YYYY-MM-DD)
            'SOURCE_FILE':   file_path,
            'SOURCE_FORMAT': 'AUS',
            'RECORD_TYPE':   'DATA',
            'FILE_ROW_NUM':  int(idx) + 2  # +2: 1 header row + 1-based index
        })

    # ── 4. Write to RAW.MEMBER_LOAD via Snowpark ──
    # column_order='name' maps only the keys present in the dict;
    # COL_07..COL_12 and LOAD_TS use their DEFAULT values (NULL / CURRENT_TIMESTAMP).
    sp_df = session.create_dataframe(rows)
    sp_df.write.mode('append').save_as_table(
        'SKYPOINTS_DB.RAW.MEMBER_LOAD',
        column_order='name'
    )

    return f'SP_LOAD_AUS_XLSX: loaded {len(rows)} rows from {file_path}'
$$;
