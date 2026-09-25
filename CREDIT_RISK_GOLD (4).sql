-- ============================================================
-- CREDIT RISK INTELLIGENCE PLATFORM
-- FINAL GOLD LAYER
-- ============================================================


-- ============================================================
-- 1. DATABASE AND SCHEMA
-- ============================================================

CREATE DATABASE IF NOT EXISTS CREDIT_RISK_DB;

CREATE SCHEMA IF NOT EXISTS CREDIT_RISK_DB.CREDIT_RISK_GOLD;

USE DATABASE CREDIT_RISK_DB;
USE SCHEMA CREDIT_RISK_GOLD;


-- ============================================================
-- 2. REMOVE REDUNDANT OLD GOLD TABLES
-- ============================================================

DROP TABLE IF EXISTS GOLD_DERIVED_FEATURES;
DROP TABLE IF EXISTS RISK_INDICATORS;
DROP TABLE IF EXISTS CUSTOMER_SEGMENTS;
DROP TABLE IF EXISTS CONTRACT_TYPE_ANALYSIS;
DROP TABLE IF EXISTS CREDIT_PERFORMANCE;
DROP TABLE IF EXISTS CUSTOMER_RISK_PROFILE;


-- ============================================================
-- 3. DIM_CUSTOMER
-- Customer master information
-- ============================================================

CREATE OR REPLACE TABLE DIM_CUSTOMER AS

SELECT DISTINCT
    SK_ID_CURR,
    CODE_GENDER,
    FLAG_OWN_CAR,
    FLAG_OWN_REALTY,
    CNT_CHILDREN,
    CNT_FAM_MEMBERS,
    NAME_EDUCATION_TYPE,
    NAME_FAMILY_STATUS,
    NAME_INCOME_TYPE,
    OCCUPATION_TYPE,
    ORGANIZATION_TYPE,
    NAME_HOUSING_TYPE,
    REGION_POPULATION_RELATIVE,
    REGION_RATING_CLIENT,
    REGION_RATING_CLIENT_W_CITY

FROM CUSTOMER_CREDIT_RISK;


-- ============================================================
-- 4. DIM_CONTRACT_TYPE
-- Loan / contract type information
-- ============================================================

CREATE OR REPLACE TABLE DIM_CONTRACT_TYPE AS

SELECT DISTINCT
    NAME_CONTRACT_TYPE AS CONTRACT_TYPE

FROM CUSTOMER_CREDIT_RISK

WHERE NAME_CONTRACT_TYPE IS NOT NULL;


-- ============================================================
-- 5. DIM_CUSTOMER_SEGMENT
-- Customer segmentation
-- ============================================================

CREATE OR REPLACE TABLE DIM_CUSTOMER_SEGMENT AS

SELECT DISTINCT

    SK_ID_CURR,

    -- Income segmentation
    CASE
        WHEN AMT_INCOME_TOTAL < 100000
            THEN 'LOW_INCOME'

        WHEN AMT_INCOME_TOTAL < 300000
            THEN 'MEDIUM_INCOME'

        ELSE 'HIGH_INCOME'
    END AS INCOME_SEGMENT,


    -- Age segmentation
    CASE
        WHEN AGE_YEARS < 25
            THEN 'YOUNG'

        WHEN AGE_YEARS < 50
            THEN 'ADULT'

        ELSE 'SENIOR'
    END AS AGE_SEGMENT,


    -- Credit exposure segmentation
    CASE
        WHEN AMT_INCOME_TOTAL IS NULL
             OR AMT_INCOME_TOTAL = 0
             OR AMT_CREDIT IS NULL
            THEN 'UNKNOWN'

        WHEN (AMT_CREDIT / AMT_INCOME_TOTAL) < 2
            THEN 'LOW_EXPOSURE'

        WHEN (AMT_CREDIT / AMT_INCOME_TOTAL) < 5
            THEN 'MEDIUM_EXPOSURE'

        ELSE 'HIGH_EXPOSURE'
    END AS CREDIT_EXPOSURE_SEGMENT

FROM CUSTOMER_CREDIT_RISK;


-- ============================================================
-- 6. FACT_CREDIT_RISK
-- Main credit risk fact table
-- ============================================================

CREATE OR REPLACE TABLE FACT_CREDIT_RISK AS

SELECT

    S.*,

    -- Customer segments
    G.INCOME_SEGMENT,
    G.AGE_SEGMENT,
    G.CREDIT_EXPOSURE_SEGMENT,


    -- Total credit exposure
    COALESCE(S.AMT_CREDIT, 0)
        + COALESCE(S.BUREAU_TOTAL_CREDIT, 0)
        AS TOTAL_CREDIT_EXPOSURE,


    -- Total debt exposure
    COALESCE(S.BUREAU_TOTAL_DEBT, 0)
        AS TOTAL_DEBT_EXPOSURE,


    -- Debt / Credit ratio
    CASE
        WHEN COALESCE(S.BUREAU_TOTAL_CREDIT, 0) > 0
        THEN
            COALESCE(S.BUREAU_TOTAL_DEBT, 0)
            / S.BUREAU_TOTAL_CREDIT

        ELSE 0
    END AS GOLD_DEBT_CREDIT_RATIO,


    -- Overdue / Credit ratio
    CASE
        WHEN COALESCE(S.BUREAU_TOTAL_CREDIT, 0) > 0
        THEN
            COALESCE(S.BUREAU_TOTAL_OVERDUE, 0)
            / S.BUREAU_TOTAL_CREDIT

        ELSE 0
    END AS GOLD_OVERDUE_CREDIT_RATIO,


    -- Maximum credit card utilization
    COALESCE(S.CC_MAX_UTILIZATION, 0)
        AS GOLD_MAX_CREDIT_UTILIZATION,


    -- Maximum payment difference
    COALESCE(S.MAX_PAYMENT_DIFFERENCE, 0)
        AS GOLD_MAX_PAYMENT_DIFFERENCE,


    -- Previous credit exposure
    COALESCE(S.PREVIOUS_TOTAL_CREDIT, 0)
        AS GOLD_PREVIOUS_CREDIT_EXPOSURE,


    -- Overdue flag
    CASE
        WHEN COALESCE(S.BUREAU_TOTAL_OVERDUE, 0) > 0
            THEN 1

        ELSE 0
    END AS OVERDUE_FLAG,


    -- Payment delay flag
    CASE
        WHEN COALESCE(S.POS_MAX_DPD, 0) > 0
          OR COALESCE(S.POS_MAX_DPD_DEF, 0) > 0
          OR COALESCE(S.MAX_PAYMENT_DIFFERENCE, 0) > 0
            THEN 1

        ELSE 0
    END AS PAYMENT_DELAY_FLAG,


    -- High credit utilization flag
    CASE
        WHEN COALESCE(S.CC_MAX_UTILIZATION, 0) >= 0.80
            THEN 1

        ELSE 0
    END AS HIGH_CREDIT_UTILIZATION_FLAG,


    -- High debt flag
    CASE
        WHEN COALESCE(S.BUREAU_TOTAL_CREDIT, 0) > 0
         AND (
             COALESCE(S.BUREAU_TOTAL_DEBT, 0)
             / S.BUREAU_TOTAL_CREDIT
         ) >= 0.70
            THEN 1

        ELSE 0
    END AS HIGH_DEBT_FLAG

FROM CUSTOMER_CREDIT_RISK S

LEFT JOIN DIM_CUSTOMER_SEGMENT G
    ON S.SK_ID_CURR = G.SK_ID_CURR;


-- ============================================================
-- 7. APPLICATION_METRICS
-- Overall loan/application metrics
-- ============================================================

CREATE OR REPLACE TABLE APPLICATION_METRICS AS

SELECT

    COUNT(*) AS APPLICATION_COUNT,

    SUM(TARGET) AS DEFAULT_COUNT,

    ROUND(
        100.0 * SUM(TARGET)
        / NULLIF(COUNT(*), 0),
        2
    ) AS DEFAULT_RATE_PERCENT,

    SUM(AMT_CREDIT) AS TOTAL_CREDIT,

    AVG(AMT_CREDIT) AS AVERAGE_CREDIT,

    AVG(AMT_INCOME_TOTAL) AS AVERAGE_INCOME

FROM FACT_CREDIT_RISK;


-- ============================================================
-- 8. SEGMENT_RISK
-- Risk analysis by customer segments
-- ============================================================

CREATE OR REPLACE TABLE SEGMENT_RISK AS


-- Income risk
SELECT

    'INCOME' AS SEGMENT_TYPE,

    INCOME_SEGMENT AS SEGMENT,

    COUNT(*) AS CUSTOMER_COUNT,

    SUM(TARGET) AS DEFAULT_COUNT,

    ROUND(
        100.0 * SUM(TARGET)
        / NULLIF(COUNT(*), 0),
        2
    ) AS DEFAULT_RATE_PERCENT,

    AVG(AMT_INCOME_TOTAL) AS AVERAGE_INCOME,

    AVG(AMT_CREDIT) AS AVERAGE_CREDIT

FROM FACT_CREDIT_RISK

GROUP BY INCOME_SEGMENT


UNION ALL


-- Age risk
SELECT

    'AGE' AS SEGMENT_TYPE,

    AGE_SEGMENT AS SEGMENT,

    COUNT(*) AS CUSTOMER_COUNT,

    SUM(TARGET) AS DEFAULT_COUNT,

    ROUND(
        100.0 * SUM(TARGET)
        / NULLIF(COUNT(*), 0),
        2
    ) AS DEFAULT_RATE_PERCENT,

    AVG(AMT_INCOME_TOTAL) AS AVERAGE_INCOME,

    AVG(AMT_CREDIT) AS AVERAGE_CREDIT

FROM FACT_CREDIT_RISK

GROUP BY AGE_SEGMENT


UNION ALL


-- Credit exposure risk
SELECT

    'CREDIT_EXPOSURE' AS SEGMENT_TYPE,

    CREDIT_EXPOSURE_SEGMENT AS SEGMENT,

    COUNT(*) AS CUSTOMER_COUNT,

    SUM(TARGET) AS DEFAULT_COUNT,

    ROUND(
        100.0 * SUM(TARGET)
        / NULLIF(COUNT(*), 0),
        2
    ) AS DEFAULT_RATE_PERCENT,

    AVG(AMT_INCOME_TOTAL) AS AVERAGE_INCOME,

    AVG(AMT_CREDIT) AS AVERAGE_CREDIT

FROM FACT_CREDIT_RISK

GROUP BY CREDIT_EXPOSURE_SEGMENT;


-- ============================================================
-- 9. CONTRACT_TYPE_RISK
-- Risk by loan type
-- ============================================================

CREATE OR REPLACE TABLE CONTRACT_TYPE_RISK AS

SELECT

    NAME_CONTRACT_TYPE AS CONTRACT_TYPE,

    COUNT(*) AS CUSTOMER_COUNT,

    SUM(TARGET) AS DEFAULT_COUNT,

    ROUND(
        100.0 * SUM(TARGET)
        / NULLIF(COUNT(*), 0),
        2
    ) AS DEFAULT_RATE_PERCENT,

    AVG(AMT_CREDIT) AS AVERAGE_CREDIT

FROM FACT_CREDIT_RISK

GROUP BY NAME_CONTRACT_TYPE;


-- ============================================================
-- 10. ML_FEATURES
-- Final dataset for Machine Learning
-- ============================================================

CREATE OR REPLACE TABLE ML_FEATURES AS

SELECT

    -- Customer ID
    F.SK_ID_CURR,

    -- Contract
    F.NAME_CONTRACT_TYPE,


    -- Customer demographics
    C.CODE_GENDER,
    C.FLAG_OWN_CAR,
    C.FLAG_OWN_REALTY,
    C.CNT_CHILDREN,
    C.CNT_FAM_MEMBERS,
    C.NAME_EDUCATION_TYPE,
    C.NAME_FAMILY_STATUS,
    C.NAME_INCOME_TYPE,
    C.OCCUPATION_TYPE,
    C.ORGANIZATION_TYPE,
    C.NAME_HOUSING_TYPE,


    -- Application information
    F.AMT_INCOME_TOTAL,
    F.AMT_CREDIT,
    F.AMT_ANNUITY,
    F.AMT_GOODS_PRICE,


    -- Derived customer features
    F.AGE_YEARS,
    F.EMPLOYMENT_YEARS,
    F.CREDIT_INCOME_RATIO,
    F.ANNUITY_INCOME_RATIO,


    -- External scores
    F.EXT_SOURCE_2,
    F.EXT_SOURCE_3,


    -- Bureau features
    F.BUREAU_ACCOUNT_COUNT,
    F.BUREAU_TOTAL_CREDIT,
    F.BUREAU_TOTAL_DEBT,
    F.BUREAU_TOTAL_OVERDUE,
    F.BUREAU_AVG_CREDIT,
    F.BUREAU_AVG_DEBT,
    F.BUREAU_MAX_CREDIT,
    F.BUREAU_MAX_DAYS_OVERDUE,


    -- Bureau balance
    F.BUREAU_BALANCE_RECORD_COUNT,
    F.BUREAU_BALANCE_ACCOUNT_COUNT,
    F.BUREAU_BALANCE_MONTH_COUNT,
    F.BUREAU_BALANCE_STATUS_COUNT,


    -- Previous applications
    F.PREVIOUS_APPLICATION_COUNT,
    F.PREVIOUS_TOTAL_APPLICATION,
    F.PREVIOUS_TOTAL_CREDIT,
    F.PREVIOUS_AVG_CREDIT,
    F.PREVIOUS_MAX_CREDIT,
    F.PREVIOUS_AVG_CREDIT_APPLICATION_RATIO,
    F.PREVIOUS_AVG_CREDIT_GOODS_RATIO,


    -- Installment features
    F.INSTALLMENT_RECORD_COUNT,
    F.TOTAL_INSTALLMENT_AMOUNT,
    F.TOTAL_PAYMENT_AMOUNT,
    F.AVG_PAYMENT_AMOUNT,
    F.AVG_PAYMENT_RATIO,
    F.MIN_PAYMENT_DIFFERENCE,
    F.MAX_PAYMENT_DIFFERENCE,


    -- POS features
    F.POS_RECORD_COUNT,
    F.POS_AVG_INSTALLMENTS,
    F.POS_MAX_INSTALLMENTS,
    F.POS_AVG_FUTURE_INSTALLMENTS,
    F.POS_MAX_DPD,
    F.POS_MAX_DPD_DEF,
    F.POS_MAX_INSTALLMENT_REMAINING,


    -- Credit card features
    F.CREDIT_CARD_RECORD_COUNT,
    F.CC_AVG_BALANCE,
    F.CC_MAX_BALANCE,
    F.CC_AVG_CREDIT_LIMIT,
    F.CC_MAX_CREDIT_LIMIT,
    F.CC_AVG_UTILIZATION,
    F.CC_MAX_UTILIZATION,
    F.CC_TOTAL_PAYMENT,


    -- Gold derived features
    F.TOTAL_CREDIT_EXPOSURE,
    F.TOTAL_DEBT_EXPOSURE,
    F.GOLD_DEBT_CREDIT_RATIO,
    F.GOLD_OVERDUE_CREDIT_RATIO,
    F.GOLD_MAX_CREDIT_UTILIZATION,
    F.GOLD_MAX_PAYMENT_DIFFERENCE,
    F.GOLD_PREVIOUS_CREDIT_EXPOSURE,


    -- Customer segments
    F.INCOME_SEGMENT,
    F.AGE_SEGMENT,
    F.CREDIT_EXPOSURE_SEGMENT,


    -- Risk indicators
    F.OVERDUE_FLAG,
    F.PAYMENT_DELAY_FLAG,
    F.HIGH_CREDIT_UTILIZATION_FLAG,
    F.HIGH_DEBT_FLAG,


    -- Target
    F.TARGET

FROM FACT_CREDIT_RISK F

LEFT JOIN DIM_CUSTOMER C
    ON F.SK_ID_CURR = C.SK_ID_CURR;


-- ============================================================
-- 11. CHECK GOLD TABLES
-- ============================================================

SHOW TABLES;


-- ============================================================
-- 12. VALIDATION - DIM_CUSTOMER
-- ============================================================

SELECT
    COUNT(*) AS TOTAL_ROWS,
    COUNT(DISTINCT SK_ID_CURR) AS UNIQUE_CUSTOMERS

FROM DIM_CUSTOMER;


-- ============================================================
-- 13. VALIDATION - FACT
-- ============================================================

SELECT
    COUNT(*) AS TOTAL_ROWS,
    COUNT(DISTINCT SK_ID_CURR) AS UNIQUE_CUSTOMERS

FROM FACT_CREDIT_RISK;


-- ============================================================
-- 14. VALIDATION - ML FEATURES
-- ============================================================

SELECT
    COUNT(*) AS TOTAL_ROWS,
    COUNT(DISTINCT SK_ID_CURR) AS UNIQUE_CUSTOMERS,
    COUNT_IF(TARGET IS NULL) AS NULL_TARGET

FROM ML_FEATURES;


-- ============================================================
-- 15. TARGET DISTRIBUTION
-- ============================================================

SELECT

    TARGET,

    COUNT(*) AS CUSTOMER_COUNT,

    ROUND(
        100.0 * COUNT(*)
        / SUM(COUNT(*)) OVER (),
        2
    ) AS PERCENTAGE

FROM ML_FEATURES

GROUP BY TARGET

ORDER BY TARGET;


-- ============================================================
-- 16. RISK FLAG SUMMARY
-- ============================================================

SELECT

    SUM(OVERDUE_FLAG)
        AS OVERDUE_CUSTOMERS,

    SUM(PAYMENT_DELAY_FLAG)
        AS PAYMENT_DELAY_CUSTOMERS,

    SUM(HIGH_CREDIT_UTILIZATION_FLAG)
        AS HIGH_UTILIZATION_CUSTOMERS,

    SUM(HIGH_DEBT_FLAG)
        AS HIGH_DEBT_CUSTOMERS

FROM FACT_CREDIT_RISK;


-- ============================================================
-- 17. APPLICATION METRICS CHECK
-- ============================================================

SELECT *

FROM APPLICATION_METRICS;


-- ============================================================
-- 18. SEGMENT RISK CHECK
-- ============================================================

SELECT *

FROM SEGMENT_RISK

ORDER BY SEGMENT_TYPE, SEGMENT;


-- ============================================================
-- 19. CONTRACT TYPE RISK CHECK
-- ============================================================

SELECT *

FROM CONTRACT_TYPE_RISK

ORDER BY CONTRACT_TYPE;


-- ============================================================
-- 20. FINAL ROW COUNT VALIDATION
-- ============================================================

SELECT
    'CUSTOMER_CREDIT_RISK' AS TABLE_NAME,
    COUNT(*) AS ROW_COUNT
FROM CUSTOMER_CREDIT_RISK

UNION ALL

SELECT
    'DIM_CUSTOMER',
    COUNT(*)
FROM DIM_CUSTOMER

UNION ALL

SELECT
    'DIM_CONTRACT_TYPE',
    COUNT(*)
FROM DIM_CONTRACT_TYPE

UNION ALL

SELECT
    'DIM_CUSTOMER_SEGMENT',
    COUNT(*)
FROM DIM_CUSTOMER_SEGMENT

UNION ALL

SELECT
    'FACT_CREDIT_RISK',
    COUNT(*)
FROM FACT_CREDIT_RISK

UNION ALL

SELECT
    'APPLICATION_METRICS',
    COUNT(*)
FROM APPLICATION_METRICS

UNION ALL

SELECT
    'SEGMENT_RISK',
    COUNT(*)
FROM SEGMENT_RISK

UNION ALL

SELECT
    'CONTRACT_TYPE_RISK',
    COUNT(*)
FROM CONTRACT_TYPE_RISK

UNION ALL

SELECT
    'ML_FEATURES',
    COUNT(*)
FROM ML_FEATURES

ORDER BY TABLE_NAME;

SELECT * FROM SEGMENT_RISK;

SELECT * FROM CREDIT_RISK_PREDICTIONS LIMIT 10;

SELECT * FROM APPLICATION_METRICS;

SELECT
    SUM(OVERDUE_FLAG) AS OVERDUE_CUSTOMERS,
    SUM(PAYMENT_DELAY_FLAG) AS PAYMENT_DELAY_CUSTOMERS,
    SUM(HIGH_CREDIT_UTILIZATION_FLAG) AS HIGH_UTILIZATION_CUSTOMERS,
    SUM(HIGH_DEBT_FLAG) AS HIGH_DEBT_CUSTOMERS
FROM FACT_CREDIT_RISK;