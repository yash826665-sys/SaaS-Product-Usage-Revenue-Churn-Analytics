/* ============================================================
   01_BASIC_ANALYSIS.SQL
   RavenStack SaaS Product, Revenue & Churn Analysis
   ------------------------------------------------------------
   Purpose: simple counting / grouping queries to get familiar
   with the dataset before moving into revenue, product usage,
   churn and support analysis.

   Note: RavenStack is a fully synthetic SaaS dataset created
   by River @ Rivalytics. No real company or customers are
   represented here.
   ============================================================ */

-- 1. Total number of accounts
SELECT COUNT(*) AS total_accounts
FROM accounts;

-- 2. Accounts by industry
SELECT industry, COUNT(*) AS n_accounts
FROM accounts
GROUP BY industry
ORDER BY n_accounts DESC;

-- 3. Accounts by country
SELECT country, COUNT(*) AS n_accounts
FROM accounts
GROUP BY country
ORDER BY n_accounts DESC;

-- 4. Accounts by plan tier (account-level plan attribute)
SELECT plan_tier, COUNT(*) AS n_accounts
FROM accounts
GROUP BY plan_tier
ORDER BY n_accounts DESC;

-- 5. Active vs churned subscriptions, and total/average current MRR
-- We treat each account's MOST RECENT subscription record (by
-- start_date) as its "current" subscription, since accounts have
-- several historical subscription rows in this dataset.
WITH latest_sub AS (
    SELECT s.*,
           ROW_NUMBER() OVER (
               PARTITION BY account_id
               ORDER BY start_date DESC, subscription_id DESC
           ) AS rn
    FROM subscriptions s
)
SELECT
    COUNT(*) AS current_accounts,
    SUM(mrr_amount) AS total_current_mrr,
    ROUND(AVG(mrr_amount), 2) AS avg_current_mrr
FROM latest_sub
WHERE rn = 1;

-- 6. Total support ticket volume and churn events logged
SELECT
    (SELECT COUNT(*) FROM support_tickets) AS total_tickets,
    (SELECT COUNT(*) FROM churn_events) AS total_churn_events;

-- 7. Account-level churn count and rate
-- accounts.churn_flag reflects each account's current status
SELECT
    SUM(CASE WHEN churn_flag = 1 THEN 1 ELSE 0 END) AS churned_accounts,
    SUM(CASE WHEN churn_flag = 0 THEN 1 ELSE 0 END) AS retained_accounts,
    ROUND(100.0 * SUM(CASE WHEN churn_flag = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS churn_rate_pct
FROM accounts;
