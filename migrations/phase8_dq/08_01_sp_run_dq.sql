-- Rules implemented:
--   01 NOT_NULL_MEMBER_ID       STG  — MEMBER_ID must not be NULL
--   02 MEMBER_ID_UNIQUE_STG     STG  — no duplicate MEMBER_IDs
--   03 VALID_ENROLLMENT_DATE    STG  — > 1900-01-01 and <= today
--   04 DOB_NOT_FUTURE           STG  — DOB <= today
--   05 VALID_AGE_RANGE          STG  — age between 18 and 120
--   06 VALID_TIER_CODE          STG  — in (PLT, GLD, SLV)
--   07 VALID_COUNTRY            STG  — country in COUNTRY_MAP
--   08 FLIGHT_AFTER_ENROLL      STG  — last_flight >= enrollment
--   09 MILES_REDEEMED_POSITIVE  CORE — miles > 0
--   10 VALID_REDEMPTION_STATUS  CORE — in (PENDING, COMPLETED, CANCELLED)
--   11 ORPHAN_REDEMPTIONS       CORE — quarantine count
--   12 RECONCILE_ROW_COUNT      STG  — raw_detail >= stg + rejects
--
-- STATUS assignment: FAIL_COUNT=0 → PASS; >0 → FAIL (or WARN for
-- non-critical rules like orphan count).
-- =============================================================

-- See SP_RUN_DQ definition in Snowflake (created live Phase 8)

-- Query DQ results:
SELECT RULE_ID, LAYER, PASS_COUNT, FAIL_COUNT, TOTAL_COUNT, STATUS, NOTES
FROM   SKYPOINTS_DB.DQ.DQ_RESULTS
ORDER  BY RUN_TS DESC, STATUS DESC, RULE_ID;
