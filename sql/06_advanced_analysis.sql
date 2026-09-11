/* ============================================================
   06_ADVANCED_analysis.SQL
   RavenStack SaaS Product, Revenue & Churn Analysis
   ------------------------------------------------------------
   Focus: a few extra window-function / multi-table examples
   plus two basic query-optimization examples with EXPLAIN
   QUERY PLAN. This file is intentionally short - the goal is
   to show good habits, not to build a tuning masterclass.
   ============================================================ */

-- 1. Customer usage over time: month-over-month change per account
-- WINDOW FUNCTION: LAG() partitioned by account to compare each
-- account's usage to its own previous month.
WITH monthly_usage AS (
    SELECT s.account_id,
           strftime('%Y-%m', f.usage_date) AS usage_month,
           SUM(f.usage_count) AS monthly_usage_count
    FROM feature_usage f
    JOIN subscriptions s ON f.subscription_id = s.subscription_id
    GROUP BY s.account_id, usage_month
)
SELECT account_id, usage_month, monthly_usage_count,
       LAG(monthly_usage_count) OVER (PARTITION BY account_id ORDER BY usage_month) AS prev_month_usage
FROM monthly_usage
ORDER BY account_id, usage_month
LIMIT 20;

-- 2. Percent of total company MRR each account represents
-- WINDOW FUNCTION: SUM() OVER () with no PARTITION BY = grand total
WITH latest_sub AS (
    SELECT s.*, ROW_NUMBER() OVER (PARTITION BY account_id ORDER BY start_date DESC) AS rn
    FROM subscriptions s
)
SELECT account_id, mrr_amount,
       ROUND(100.0 * mrr_amount / SUM(mrr_amount) OVER (), 2) AS pct_of_total_mrr
FROM latest_sub
WHERE rn = 1
ORDER BY pct_of_total_mrr DESC
LIMIT 10;

-- 3. Full picture join: accounts + subscriptions + usage + support + churn
-- COMPLEX JOIN across 5 tables to build one denormalized view
-- for a small set of accounts (useful for spot-checking records).
WITH latest_sub AS (
    SELECT s.*, ROW_NUMBER() OVER (PARTITION BY account_id ORDER BY start_date DESC) AS rn
    FROM subscriptions s
),
usage_summary AS (
    SELECT s.account_id, SUM(f.usage_count) AS total_usage
    FROM feature_usage f
    JOIN subscriptions s ON f.subscription_id = s.subscription_id
    GROUP BY s.account_id
),
ticket_summary AS (
    SELECT account_id, COUNT(*) AS n_tickets
    FROM support_tickets
    GROUP BY account_id
)
SELECT a.account_id, a.industry, l.plan_tier, l.mrr_amount,
       u.total_usage, t.n_tickets, a.churn_flag
FROM accounts a
JOIN latest_sub l ON a.account_id = l.account_id AND l.rn = 1
LEFT JOIN usage_summary u ON a.account_id = u.account_id
LEFT JOIN ticket_summary t ON a.account_id = t.account_id
ORDER BY l.mrr_amount DESC
LIMIT 10;

-- 4. Small-account vs large-account segmentation using CASE WHEN on seats
SELECT
    CASE
        WHEN seats <= 10 THEN 'Small'
        WHEN seats <= 25 THEN 'Medium'
        ELSE 'Large'
    END AS account_size,
    COUNT(*) AS n_accounts,
    ROUND(AVG(seats), 1) AS avg_seats
FROM accounts
GROUP BY account_size
ORDER BY avg_seats;

-- 5. QUERY OPTIMIZATION EXAMPLE 1
-- Before: selects every column and filters AFTER joining all tables.
-- This forces the database to carry unused columns through the whole join.
--
-- SELECT * 
-- FROM accounts a
-- JOIN subscriptions s ON a.account_id = s.account_id
-- WHERE a.industry = 'FinTech';
--
-- After: select only the columns actually needed, which reduces
-- the amount of data the engine has to move around.
EXPLAIN QUERY PLAN
SELECT a.account_id, a.industry, s.mrr_amount
FROM accounts a
JOIN subscriptions s ON a.account_id = s.account_id
WHERE a.industry = 'FinTech';

-- 6. QUERY OPTIMIZATION EXAMPLE 2
-- Filtering early: apply the WHERE condition inside a CTE/subquery
-- before joining, instead of joining the full table and filtering after.
-- This keeps the join smaller.
EXPLAIN QUERY PLAN
WITH fintech_accounts AS (
    SELECT account_id FROM accounts WHERE industry = 'FinTech'
)
SELECT s.account_id, s.mrr_amount
FROM subscriptions s
JOIN fintech_accounts f ON s.account_id = f.account_id;

-- Note on indexes: account_id and subscription_id are the join keys
-- used throughout this project. In a production database these
-- columns would normally have indexes (e.g.
-- CREATE INDEX idx_subscriptions_account_id ON subscriptions(account_id);)
-- to speed up the joins above. This is mentioned for learning purposes;
-- no index was actually created for this small demo database.
