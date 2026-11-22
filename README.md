# SkyPoints Loyalty Pipeline — Incubyte Data Engineer Assessment

End-to-end, idempotent, set-based Snowflake data pipeline for a multi-country
airline loyalty programme.

---

## Architecture

```
Flat File (pipe-delimited, H/D rows)   India CSV   USA CSV   Canada CSV   NDJSON
         │                                │           │          │            │
   @STG_MEMBER_ORIGINAL          @STG_MEMBER_INDIA  @STG_MEMBER_USA  @STG_MEMBER_CANADA  @STG_REDEMPTIONS
         └──────────────────────────────────────────────────────────┘            │
                                     COPY INTO                                   │
                              RAW.MEMBER_LOAD                       RAW.REDEMPTIONS_RAW
                                (all VARCHAR)                           (VARIANT)
                                     │                                           │
                           SP_LOAD_STG_MEMBER                   SP_LOAD_REDEMPTIONS
                            (Phase 5 MERGE)                       (Phase 7 MERGE)
                                     │                                           │
                              STG.MEMBER ──► STG.MEMBER_REJECT    REDEMPTIONS_FLAT
                                     │                             REDEMPTIONS_QUARANTINE
                           SP_LOAD_CORE_MEMBERS                                  │
                            (Phase 6 MERGE)                                      │
                      ┌──────┬────────┬─────────┐                               │
                 TABLE_INDIA TABLE_USA TABLE_CANADA TABLE_OTHER                   │
                      └──────┴────────┴─────────┘                               │
                                     │                                           │
                              V_ALL_MEMBERS (UNION ALL) ◄──────── JOIN ──────────┘
                                     │
                              SP_RUN_DQ → DQ.DQ_RESULTS
                                     │
                           TASK CHAIN (every 15 min, stream-gated)
```

---

## Phases

| # | Phase | Key Objects |
|---|-------|-------------|
| 1 | Infrastructure | `SKYPOINTS_DB`, 4 schemas, `WH_SKYPOINTS` |
| 2 | DDL | All tables, file formats, internal stages, `COUNTRY_MAP` |
| 3 | Sample data | 4 member files + 1 NDJSON, all edge cases |
| 4 | RAW load | `COPY INTO` with `ON_ERROR=CONTINUE` + `METADATA$FILENAME` |
| 5 | STG | `SP_LOAD_STG_MEMBER` — MERGE + reject routing |
| 6 | CORE | `SP_LOAD_CORE_MEMBERS` — 4 country tables + cross-country delete |
| 7 | JSON | `SP_LOAD_REDEMPTIONS` — `LATERAL FLATTEN` + quarantine + `V_ALL_MEMBERS` |
| 8 | DQ | `SP_RUN_DQ` — 12 rules logged to `DQ.DQ_RESULTS` |
| 9 | Orchestration | Streams + 5-task DAG + Snowpipe stub |
| 10 | Tests | 20 SQL assertions (all PASS) |

---

## Documented Assumptions

| # | Assumption | Reason |
|---|-----------|--------|
| A1 | **`MEMBER_ID` is the real primary key**, not `Member_Name` | The spec marks `Member_Name` as the key column. Names are not unique identifiers and change over time. `MEMBER_ID` is used for all MERGE, dedup, and DQ uniqueness checks. |
| A2 | Original feed DOB format is `MMDDYYYY` (not `YYYYMMDD`) | `03051985` with `YYYYMMDD` yields year 0305 — invalid. Interpreted as `MMDDYYYY` = March 05, 1985 ✓ |
| A3 | DOB leading-zero fix: `LPAD(dob_col, 8, '0')` before `TRY_TO_DATE` | Source drops the leading zero: `3051985` (7 chars) → `03051985` (8 chars) ✓ |
| A4 | `STALE_MEMBER = 'Y'` when `LAST_FLIGHT_DATE IS NULL` | Conservative default — no recorded flight = treat as stale. |
| A5 | India `Individual` column (`I`/`C`) stored as `MEMBER_TYPE`; `NULL` for all other feeds | Not in the original spec; preserved for completeness and future use. |
| A6 | `MEMBER_ID` global uniqueness: India/USA/Canada local IDs (1,2,3) differ from original global IDs (223457…) | In the sample data there is no collision. In production, source teams must guarantee globally unique IDs or a composite key (source + local_id) must be introduced. |
| A7 | Country normalisation via `COUNTRY_MAP`: `IND/IN → IND`, `AU/AUS → AUS`, `PHIL/PHL → PHL`, etc. | Inconsistent source codes mapped to ISO-3 canonical values. |
| A8 | Invalid dates (`2021-13-13`, `13/13/1952`) become `NULL` via `TRY_TO_DATE`; row stays in STG with `DQ_STATUS = 'WARN'` | Never reject on bad dates; flag for downstream remediation. |
| A9 | Literal `'NULL'` string in source is mapped to SQL `NULL` via `NULL_IF` in the CSV file format | `FF_MEMBER_CSV` has `NULL_IF = ('NULL','null','N/A','')` |
| A10 | Redemption status transitions: `PENDING → COMPLETED` allowed; backward transitions not prevented at MERGE level | MERGE uses latest `FILE_ROW_NUM` wins; no state-machine guard implemented — simpler for the assessment. Document as a production enhancement. |
| A11 | Canada feed has no `DOB` column → `DOB = NULL` for all Canada members | Assumption: Canada source does not capture birth date. |
| A12 | Reconciliation formula: `raw_detail >= stg + rejects` | Dedup intentionally reduces the count; the formula correctly accepts `deduped=2` as expected. |

---

## Scale Notes

| Concern | Approach |
|---------|----------|
| Billions of rows | All transformations are set-based SQL (MERGE/INSERT SELECT/LATERAL FLATTEN). No row-by-row cursors or Python loops. |
| Dedup at scale | `QUALIFY ROW_NUMBER() OVER (PARTITION BY MEMBER_ID ...)` is fully parallel in Snowflake. |
| Country routing | 4 separate MERGE statements (one per table) are more efficient than dynamic SQL for the optimizer at scale. |
| Incremental load | Streams (`APPEND_ONLY`) + Tasks ensure only net-new rows are processed each cycle, not full rescans. |
| Clustering | `RAW.MEMBER_LOAD` benefits from clustering on `(SOURCE_FORMAT, RECORD_TYPE)` for large-scale pruning. Add `CLUSTER BY (SOURCE_FORMAT, RECORD_TYPE)` in production. |
| JSON at scale | `LATERAL FLATTEN` is a Snowflake native operation and scales horizontally. Each NDJSON row contains one member's redemptions array; files should be split into chunks of ~100 MB for optimal micro-partition parallelism. |
| Warehouse sizing | `WH_SKYPOINTS` is `X-Small` for the assessment. Scale to `Medium`–`Large` for production volumes; consider multi-cluster for concurrent pipeline runs. |

---

## Running the Pipeline

```bash
# 1. Execute DDL (phases 1-2)
snowsql -f migrations/phase1_infrastructure/01_warehouse.sql
snowsql -f migrations/phase1_infrastructure/02_database.sql
snowsql -f migrations/phase1_infrastructure/03_schemas.sql
snowsql -f migrations/phase2_ddl/02_01_file_formats_and_stages.sql
# ... (all 02_xx files)

# 2. Upload sample files (phase 3) — via snowflake-connector PUT or SnowSQL
# python3 upload_samples.py   OR   snowsql PUT commands

# 3. Load RAW (phase 4)
snowsql -f migrations/phase3_sample_data/03_04_copy_into_raw.sql

# 4-8. Run procedures
CALL SKYPOINTS_DB.STG.SP_LOAD_STG_MEMBER();
CALL SKYPOINTS_DB.CORE.SP_LOAD_CORE_MEMBERS();
CALL SKYPOINTS_DB.CORE.SP_LOAD_REDEMPTIONS();
CALL SKYPOINTS_DB.DQ.SP_RUN_DQ();

# 9. Enable task chain (already RESUMED)
# Tasks fire automatically every 15 min when streams have data.

# 10. Run tests
snowsql -f migrations/phase10_tests/10_01_test_suite.sql
```

---

## Project Structure

```
skypoints-pipeline/
├── README.md
├── .gitignore
├── sample_data/
│   ├── members_original.csv      # Pipe-delimited H/D feed (5 members, edge cases)
│   ├── members_india.csv         # M/D/YYYY dates, Individual flag, invalid DOB
│   ├── members_usa.csv           # YYYY-MM-DD, NULL string, invalid date
│   ├── members_canada.csv        # Unpadded MMDDYYYY dates
│   └── redemptions.ndjson        # PENDING→COMPLETED, orphan, invalid status
└── migrations/
    ├── phase1_infrastructure/    # Warehouse, DB, schemas
    ├── phase2_ddl/               # All table DDL, file formats, stages
    ├── phase3_sample_data/       # COPY INTO commands
    ├── phase5_stg/               # SP_LOAD_STG_MEMBER
    ├── phase6_core/              # SP_LOAD_CORE_MEMBERS
    ├── phase7_json/              # SP_LOAD_REDEMPTIONS, V_ALL_MEMBERS
    ├── phase8_dq/                # SP_RUN_DQ
    ├── phase9_orchestration/     # Streams, Tasks, Snowpipe stub
    └── phase10_tests/            # 20 SQL test assertions
```
