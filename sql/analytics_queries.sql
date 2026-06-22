-- ============================================================================
-- NorthBridge Bank — Retail Banking Growth & Retention Strategy
-- Phase 4: SQL Analytics Layer
-- Engine target: PostgreSQL / Snowflake / SQL Server compatible (ANSI SQL)
-- ============================================================================

-- ============================================================================
-- SECTION 1: TABLE CREATION (DDL)
-- ============================================================================

DROP TABLE IF EXISTS customer_master;
CREATE TABLE customer_master (
    customer_id            INT PRIMARY KEY,
    segment                VARCHAR(30) NOT NULL,
    age                    INT NOT NULL,
    gender                 VARCHAR(20),
    occupation              VARCHAR(50),
    income_band            VARCHAR(20),
    immigration_status     VARCHAR(30),
    region                 VARCHAR(30),
    household_size         INT,
    relationship_status    VARCHAR(20),
    years_with_bank        DECIMAL(5,2),
    has_direct_deposit     BOOLEAN,
    churn_flag             BOOLEAN
);

DROP TABLE IF EXISTS product_holdings;
CREATE TABLE product_holdings (
    customer_id                INT NOT NULL REFERENCES customer_master(customer_id),
    product                     VARCHAR(30) NOT NULL,
    balance                     DECIMAL(14,2),
    monthly_revenue_estimate    DECIMAL(10,2),
    open_date                   DATE
);

DROP TABLE IF EXISTS transaction_summary;
CREATE TABLE transaction_summary (
    customer_id         INT NOT NULL REFERENCES customer_master(customer_id),
    txn_year             INT NOT NULL,
    txn_month            INT NOT NULL,
    total_deposits        DECIMAL(12,2),
    total_spend           DECIMAL(12,2),
    bill_payments          INT,
    etransfer_count        INT,
    atm_withdrawals        INT
);

DROP TABLE IF EXISTS digital_engagement;
CREATE TABLE digital_engagement (
    customer_id                    INT PRIMARY KEY REFERENCES customer_master(customer_id),
    mobile_usage_score              DECIMAL(5,1),
    online_banking_score            DECIMAL(5,1),
    monthly_logins                  INT,
    uses_mobile_app                 BOOLEAN,
    uses_online_banking             BOOLEAN,
    has_etransfer_setup             BOOLEAN,
    digital_onboarding_completed    BOOLEAN
);

DROP TABLE IF EXISTS branch_interaction;
CREATE TABLE branch_interaction (
    customer_id                INT PRIMARY KEY REFERENCES customer_master(customer_id),
    branch_visits_annual        INT,
    advisor_meetings_annual     INT,
    service_tickets             INT,
    complaints_filed            INT,
    product_inquiries           INT
);

DROP TABLE IF EXISTS customer_satisfaction;
CREATE TABLE customer_satisfaction (
    customer_id            INT PRIMARY KEY REFERENCES customer_master(customer_id),
    nps_score               INT,
    csat_score               DECIMAL(3,1),
    complaint_count          INT,
    avg_resolution_days      DECIMAL(5,1),
    last_survey_month        INT
);

-- Helpful indexes for analytic joins
CREATE INDEX idx_product_customer ON product_holdings(customer_id);
CREATE INDEX idx_txn_customer ON transaction_summary(customer_id);
CREATE INDEX idx_cm_segment ON customer_master(segment);
CREATE INDEX idx_cm_region ON customer_master(region);
CREATE INDEX idx_cm_churn ON customer_master(churn_flag);


-- ============================================================================
-- SECTION 2: CHURN ANALYTICS
-- ============================================================================

-- 2.1 Overall churn rate
SELECT
    COUNT(*)                                       AS total_customers,
    SUM(CASE WHEN churn_flag THEN 1 ELSE 0 END)    AS churned_customers,
    ROUND(100.0 * AVG(CASE WHEN churn_flag THEN 1.0 ELSE 0.0 END), 2) AS churn_rate_pct
FROM customer_master;

-- 2.2 Churn rate by segment
SELECT
    segment,
    COUNT(*)                                                          AS customers,
    SUM(CASE WHEN churn_flag THEN 1 ELSE 0 END)                       AS churned,
    ROUND(100.0 * AVG(CASE WHEN churn_flag THEN 1.0 ELSE 0.0 END), 2) AS churn_rate_pct
FROM customer_master
GROUP BY segment
ORDER BY churn_rate_pct DESC;

-- 2.3 Churn rate by region
SELECT
    region,
    COUNT(*)                                                          AS customers,
    SUM(CASE WHEN churn_flag THEN 1 ELSE 0 END)                       AS churned,
    ROUND(100.0 * AVG(CASE WHEN churn_flag THEN 1.0 ELSE 0.0 END), 2) AS churn_rate_pct
FROM customer_master
GROUP BY region
ORDER BY churn_rate_pct DESC;

-- 2.4 Churn rate by segment x region (cross-tab, top 20 combinations by volume)
SELECT
    segment,
    region,
    COUNT(*)                                                          AS customers,
    ROUND(100.0 * AVG(CASE WHEN churn_flag THEN 1.0 ELSE 0.0 END), 2) AS churn_rate_pct
FROM customer_master
GROUP BY segment, region
ORDER BY customers DESC
LIMIT 20;

-- 2.5 Churn rate by tenure band
SELECT
    CASE
        WHEN years_with_bank < 1  THEN '0. Under 1 year'
        WHEN years_with_bank < 3  THEN '1. 1-3 years'
        WHEN years_with_bank < 5  THEN '2. 3-5 years'
        WHEN years_with_bank < 10 THEN '3. 5-10 years'
        ELSE '4. 10+ years'
    END AS tenure_band,
    COUNT(*)                                                          AS customers,
    ROUND(100.0 * AVG(CASE WHEN churn_flag THEN 1.0 ELSE 0.0 END), 2) AS churn_rate_pct
FROM customer_master
GROUP BY tenure_band
ORDER BY tenure_band;

-- 2.6 Churn rate by direct deposit status
SELECT
    has_direct_deposit,
    COUNT(*)                                                          AS customers,
    ROUND(100.0 * AVG(CASE WHEN churn_flag THEN 1.0 ELSE 0.0 END), 2) AS churn_rate_pct
FROM customer_master
GROUP BY has_direct_deposit;

-- 2.7 Churn rate by product count band (requires product join, see Section 4 CTE)
WITH product_counts AS (
    SELECT customer_id, COUNT(*) AS product_count
    FROM product_holdings
    GROUP BY customer_id
)
SELECT
    CASE
        WHEN COALESCE(pc.product_count, 0) <= 2 THEN '0. 0-2 products'
        WHEN pc.product_count <= 4             THEN '1. 3-4 products'
        WHEN pc.product_count <= 6             THEN '2. 5-6 products'
        ELSE '3. 7+ products'
    END AS product_band,
    COUNT(*)                                                          AS customers,
    ROUND(100.0 * AVG(CASE WHEN cm.churn_flag THEN 1.0 ELSE 0.0 END), 2) AS churn_rate_pct
FROM customer_master cm
LEFT JOIN product_counts pc ON cm.customer_id = pc.customer_id
GROUP BY product_band
ORDER BY product_band;


-- ============================================================================
-- SECTION 3: CUSTOMER LIFETIME VALUE (CLV)
-- ============================================================================

-- 3.1 Monthly revenue and implied 5-year CLV by segment
-- (Simple proxy: CLV = monthly_revenue * 12 * avg_retention_multiplier)
WITH customer_revenue AS (
    SELECT
        cm.customer_id,
        cm.segment,
        cm.churn_flag,
        COALESCE(SUM(ph.monthly_revenue_estimate), 0) AS monthly_revenue
    FROM customer_master cm
    LEFT JOIN product_holdings ph ON cm.customer_id = ph.customer_id
    GROUP BY cm.customer_id, cm.segment, cm.churn_flag
),
retention_multiplier AS (
    SELECT 'Students' AS segment, 2.85 AS multiplier
    UNION ALL SELECT 'Young Professionals', 4.36
    UNION ALL SELECT 'Families', 4.85
    UNION ALL SELECT 'Newcomers to Canada', 3.04
    UNION ALL SELECT 'Affluent Customers', 4.93
)
SELECT
    cr.segment,
    COUNT(*)                                                AS customers,
    ROUND(AVG(cr.monthly_revenue), 2)                       AS avg_monthly_revenue,
    ROUND(AVG(cr.monthly_revenue) * 12 * rm.multiplier, 0)  AS avg_5yr_clv_proxy,
    ROUND(SUM(cr.monthly_revenue) * 12 * rm.multiplier, 0)  AS total_5yr_clv_proxy
FROM customer_revenue cr
JOIN retention_multiplier rm ON cr.segment = rm.segment
GROUP BY cr.segment, rm.multiplier
ORDER BY avg_5yr_clv_proxy DESC;

-- 3.2 CLV at risk (churned customers only)
WITH customer_revenue AS (
    SELECT
        cm.customer_id,
        cm.segment,
        cm.churn_flag,
        COALESCE(SUM(ph.monthly_revenue_estimate), 0) AS monthly_revenue
    FROM customer_master cm
    LEFT JOIN product_holdings ph ON cm.customer_id = ph.customer_id
    GROUP BY cm.customer_id, cm.segment, cm.churn_flag
),
retention_multiplier AS (
    SELECT 'Students' AS segment, 2.85 AS multiplier
    UNION ALL SELECT 'Young Professionals', 4.36
    UNION ALL SELECT 'Families', 4.85
    UNION ALL SELECT 'Newcomers to Canada', 3.04
    UNION ALL SELECT 'Affluent Customers', 4.93
)
SELECT
    cr.segment,
    COUNT(*)                                               AS churned_customers,
    ROUND(SUM(cr.monthly_revenue) * 12 * rm.multiplier, 0) AS clv_at_risk
FROM customer_revenue cr
JOIN retention_multiplier rm ON cr.segment = rm.segment
WHERE cr.churn_flag = TRUE
GROUP BY cr.segment, rm.multiplier
ORDER BY clv_at_risk DESC;


-- ============================================================================
-- SECTION 4: PRODUCT PENETRATION & CROSS-SELL
-- ============================================================================

-- 4.1 Product-level penetration rate across full portfolio
SELECT
    ph.product,
    COUNT(DISTINCT ph.customer_id)                                              AS customers_holding,
    ROUND(100.0 * COUNT(DISTINCT ph.customer_id) /
        (SELECT COUNT(*) FROM customer_master), 2)                              AS penetration_rate_pct,
    ROUND(AVG(ph.balance), 0)                                                   AS avg_balance,
    ROUND(AVG(ph.monthly_revenue_estimate), 2)                                  AS avg_monthly_revenue
FROM product_holdings ph
GROUP BY ph.product
ORDER BY penetration_rate_pct DESC;

-- 4.2 Product penetration by segment
SELECT
    cm.segment,
    ph.product,
    COUNT(DISTINCT ph.customer_id)                                  AS customers_holding,
    ROUND(100.0 * COUNT(DISTINCT ph.customer_id) /
        (SELECT COUNT(*) FROM customer_master cm2
         WHERE cm2.segment = cm.segment), 1)                        AS penetration_rate_pct
FROM customer_master cm
JOIN product_holdings ph ON cm.customer_id = ph.customer_id
GROUP BY cm.segment, ph.product
ORDER BY cm.segment, penetration_rate_pct DESC;

-- 4.3 Average product count per customer by segment
WITH product_counts AS (
    SELECT customer_id, COUNT(*) AS product_count
    FROM product_holdings
    GROUP BY customer_id
)
SELECT
    cm.segment,
    ROUND(AVG(COALESCE(pc.product_count, 0)), 2) AS avg_product_count,
    MIN(COALESCE(pc.product_count, 0))           AS min_products,
    MAX(COALESCE(pc.product_count, 0))           AS max_products
FROM customer_master cm
LEFT JOIN product_counts pc ON cm.customer_id = pc.customer_id
GROUP BY cm.segment
ORDER BY avg_product_count DESC;

-- 4.4 Cross-sell opportunity: customers with chequing but no TFSA (savings gap)
SELECT
    cm.segment,
    COUNT(DISTINCT cm.customer_id) AS chequing_no_tfsa_customers
FROM customer_master cm
JOIN product_holdings ph_chq ON cm.customer_id = ph_chq.customer_id AND ph_chq.product = 'Chequing'
WHERE NOT EXISTS (
    SELECT 1 FROM product_holdings ph_tfsa
    WHERE ph_tfsa.customer_id = cm.customer_id AND ph_tfsa.product = 'TFSA'
)
GROUP BY cm.segment
ORDER BY chequing_no_tfsa_customers DESC;

-- 4.5 Mortgage-eligible non-mortgage holders (Young Professionals, age 28+, no mortgage)
SELECT
    cm.customer_id,
    cm.age,
    cm.income_band,
    cm.years_with_bank
FROM customer_master cm
WHERE cm.segment = 'Young Professionals'
  AND cm.age >= 28
  AND cm.churn_flag = FALSE
  AND NOT EXISTS (
      SELECT 1 FROM product_holdings ph
      WHERE ph.customer_id = cm.customer_id AND ph.product = 'Mortgage'
  )
ORDER BY cm.years_with_bank DESC;


-- ============================================================================
-- SECTION 5: DIGITAL ENGAGEMENT ANALYSIS
-- ============================================================================

-- 5.1 Digital engagement metrics: churned vs retained
SELECT
    cm.churn_flag,
    ROUND(AVG(de.mobile_usage_score), 1)        AS avg_mobile_score,
    ROUND(AVG(de.monthly_logins), 1)             AS avg_monthly_logins,
    ROUND(100.0 * AVG(CASE WHEN de.uses_mobile_app THEN 1.0 ELSE 0.0 END), 1) AS pct_uses_app,
    ROUND(100.0 * AVG(CASE WHEN de.digital_onboarding_completed THEN 1.0 ELSE 0.0 END), 1) AS pct_digital_onboarded
FROM customer_master cm
JOIN digital_engagement de ON cm.customer_id = de.customer_id
GROUP BY cm.churn_flag;

-- 5.2 Digital engagement by segment
SELECT
    cm.segment,
    ROUND(AVG(de.mobile_usage_score), 1)  AS avg_mobile_score,
    ROUND(AVG(de.monthly_logins), 1)       AS avg_monthly_logins,
    ROUND(100.0 * AVG(CASE WHEN de.uses_mobile_app THEN 1.0 ELSE 0.0 END), 1) AS pct_uses_app
FROM customer_master cm
JOIN digital_engagement de ON cm.customer_id = de.customer_id
GROUP BY cm.segment
ORDER BY avg_mobile_score DESC;


-- ============================================================================
-- SECTION 6: SATISFACTION & SERVICE ANALYSIS
-- ============================================================================

-- 6.1 NPS and CSAT by segment
SELECT
    cm.segment,
    ROUND(AVG(cs.nps_score), 1)            AS avg_nps,
    ROUND(AVG(cs.csat_score), 2)            AS avg_csat,
    ROUND(AVG(cs.complaint_count), 2)       AS avg_complaints,
    ROUND(AVG(cs.avg_resolution_days), 1)   AS avg_resolution_days
FROM customer_master cm
JOIN customer_satisfaction cs ON cm.customer_id = cs.customer_id
GROUP BY cm.segment
ORDER BY avg_nps DESC;

-- 6.2 Churn rate by complaint volume
SELECT
    cs.complaint_count,
    COUNT(*)                                                          AS customers,
    ROUND(100.0 * AVG(CASE WHEN cm.churn_flag THEN 1.0 ELSE 0.0 END), 2) AS churn_rate_pct
FROM customer_master cm
JOIN customer_satisfaction cs ON cm.customer_id = cs.customer_id
GROUP BY cs.complaint_count
ORDER BY cs.complaint_count;

-- 6.3 Branch and advisor engagement by segment
SELECT
    cm.segment,
    ROUND(AVG(bi.branch_visits_annual), 2)       AS avg_branch_visits,
    ROUND(AVG(bi.advisor_meetings_annual), 2)    AS avg_advisor_meetings,
    ROUND(AVG(bi.complaints_filed), 2)            AS avg_complaints_filed
FROM customer_master cm
JOIN branch_interaction bi ON cm.customer_id = bi.customer_id
GROUP BY cm.segment
ORDER BY avg_advisor_meetings DESC;


-- ============================================================================
-- SECTION 7: TRANSACTION BEHAVIOR
-- ============================================================================

-- 7.1 Average monthly deposits and spend by segment
SELECT
    cm.segment,
    ROUND(AVG(ts.total_deposits), 0)   AS avg_monthly_deposits,
    ROUND(AVG(ts.total_spend), 0)       AS avg_monthly_spend,
    ROUND(AVG(ts.etransfer_count), 1)   AS avg_etransfers_per_month
FROM customer_master cm
JOIN transaction_summary ts ON cm.customer_id = ts.customer_id
GROUP BY cm.segment
ORDER BY avg_monthly_deposits DESC;

-- 7.2 Monthly deposit trend across the year (portfolio-wide)
SELECT
    ts.txn_month,
    ROUND(AVG(ts.total_deposits), 0)  AS avg_deposits,
    ROUND(AVG(ts.total_spend), 0)      AS avg_spend
FROM transaction_summary ts
GROUP BY ts.txn_month
ORDER BY ts.txn_month;


-- ============================================================================
-- SECTION 8: HIGH-VALUE RETENTION TARGET LIST
-- (Customers not yet churned, high CLV proxy, elevated risk signals)
-- ============================================================================

WITH customer_revenue AS (
    SELECT
        cm.customer_id,
        cm.segment,
        cm.region,
        cm.churn_flag,
        cm.has_direct_deposit,
        cm.years_with_bank,
        COALESCE(SUM(ph.monthly_revenue_estimate), 0) AS monthly_revenue,
        COUNT(ph.product)                              AS product_count
    FROM customer_master cm
    LEFT JOIN product_holdings ph ON cm.customer_id = ph.customer_id
    GROUP BY cm.customer_id, cm.segment, cm.region, cm.churn_flag,
             cm.has_direct_deposit, cm.years_with_bank
),
scored AS (
    SELECT
        cr.*,
        cs.nps_score,
        cs.complaint_count,
        (CASE WHEN cr.product_count <= 2 THEN 25 ELSE 0 END +
         CASE WHEN cr.has_direct_deposit = FALSE THEN 20 ELSE 0 END +
         CASE WHEN cs.complaint_count >= 2 THEN 15 ELSE 0 END +
         CASE WHEN cs.nps_score < 0 THEN 10 ELSE 0 END +
         CASE WHEN cr.years_with_bank < 1 THEN 10 ELSE 0 END
        ) AS risk_score
    FROM customer_revenue cr
    JOIN customer_satisfaction cs ON cr.customer_id = cs.customer_id
)
SELECT
    customer_id, segment, region, monthly_revenue, product_count,
    has_direct_deposit, nps_score, complaint_count, risk_score
FROM scored
WHERE churn_flag = FALSE
  AND risk_score >= 35
  AND monthly_revenue >= 100
ORDER BY risk_score DESC, monthly_revenue DESC
LIMIT 100;


-- ============================================================================
-- SECTION 9: EXECUTIVE KPI SUMMARY VIEW (for BI tool consumption)
-- ============================================================================

CREATE OR REPLACE VIEW vw_executive_kpi_summary AS
WITH product_counts AS (
    SELECT customer_id, COUNT(*) AS product_count, SUM(balance) AS total_balance,
           SUM(monthly_revenue_estimate) AS monthly_revenue
    FROM product_holdings
    GROUP BY customer_id
)
SELECT
    cm.customer_id,
    cm.segment,
    cm.region,
    cm.age,
    cm.income_band,
    cm.years_with_bank,
    cm.has_direct_deposit,
    cm.churn_flag,
    COALESCE(pc.product_count, 0)      AS product_count,
    COALESCE(pc.total_balance, 0)      AS total_balance,
    COALESCE(pc.monthly_revenue, 0)    AS monthly_revenue,
    de.mobile_usage_score,
    de.monthly_logins,
    de.uses_mobile_app,
    cs.nps_score,
    cs.csat_score,
    cs.complaint_count,
    bi.branch_visits_annual,
    bi.advisor_meetings_annual
FROM customer_master cm
LEFT JOIN product_counts pc ON cm.customer_id = pc.customer_id
LEFT JOIN digital_engagement de ON cm.customer_id = de.customer_id
LEFT JOIN customer_satisfaction cs ON cm.customer_id = cs.customer_id
LEFT JOIN branch_interaction bi ON cm.customer_id = bi.customer_id;

-- Usage: SELECT * FROM vw_executive_kpi_summary WHERE segment = 'Young Professionals';
