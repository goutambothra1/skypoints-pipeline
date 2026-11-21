# SkyPoints Loyalty Pipeline

End-to-end Snowflake data pipeline for the **Incubyte Data Engineer Assessment** —
a "SkyPoints" airline loyalty programme built entirely on Snowflake using
set-based SQL, fully idempotent scripts, and a clean four-layer architecture.

## Architecture

```
Flat File  (pipe-delimited, H / D row types)
     │
 @RAW.MEMBER_STAGE
     │  COPY INTO
 RAW.MEMBER_LOAD          ← raw 12-column landing + file metadata
     │  MERGE (filter D rows, type-cast, dedup)
 STG.MEMBER               STG.MEMBER_REJECT
     │  MERGE SCD-1
 CORE.DIM_MEMBER  ◄──────  CORE.DIM_TIER  (reference)
     │
 DQ.DQ_RESULTS            (9 set-based rules, one row per check per batch)
     │
 TASK CHAIN               RAW → STG → CORE → DQ
```

## Layers

| Schema | Purpose |
|--------|---------|
| `RAW`  | Flat-file landing; all rows ingested verbatim including header rows |
| `STG`  | Filtered (D rows only), type-cast, deduplicated |
| `CORE` | Dimensional model — `DIM_MEMBER`, `DIM_TIER` |
| `DQ`   | Rule-engine results for every pipeline run |

## Warehouse

`WH_SKYPOINTS` — X-Small, auto-suspend 60 s, auto-resume.

## Phases

| Phase | Description |
|-------|-------------|
| 1 | Infrastructure — DB, schemas, warehouse |
| 2 | RAW layer — file format, stage, landing table, COPY |
| 3 | STG layer — MERGE procedure + reject table |
| 4 | CORE layer — DIM_TIER seed + DIM_MEMBER MERGE procedure |
| 5 | DQ layer — rule engine (9 rules) |
| 6 | Orchestration — chained Tasks + smoke test |

## Running the scripts

Execute files in numeric order within each phase directory:

```bash
# Example — Phase 1
snowsql -f migrations/phase1_infrastructure/01_warehouse.sql
snowsql -f migrations/phase1_infrastructure/02_database.sql
snowsql -f migrations/phase1_infrastructure/03_schemas.sql
```

## Design decisions

- **Idempotent everywhere** — `CREATE … IF NOT EXISTS`, `MERGE` (not INSERT), `CREATE OR REPLACE` only for procedures/views.
- **Set-based only** — no row-by-row cursors or loops.
- **H/D row filtering** — the file's leading `|` produces an empty `$1`; `$2` carries the record-type flag. Header rows are stored in RAW but excluded in STG by `WHERE REC_TYPE = 'D'`.
- **Scalability** — MERGE keys are the natural business key (`MEMBER_ID`); clustering on `REC_TYPE` in `RAW.MEMBER_LOAD` keeps pruning efficient at scale.
