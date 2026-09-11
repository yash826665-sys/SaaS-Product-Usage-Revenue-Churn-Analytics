/* ============================================================
   02_REVENUE_ANALYSIS.SQL
   RavenStack SaaS Product, Revenue & Churn Analysis
   ------------------------------------------------------------
   Focus: MRR, plan revenue, account value, revenue over time.
   Uses window functions, CTEs, subqueries and conditional
   aggregation on top of the subscriptions and accounts tables.
   ============================================================ */

-- 1. Revenue (current MRR) by plan tier
-- Uses the plan_tier recorded on the LATEST subscription itself,
-- since MRR is a subscription-level fact.
WITH latest_sub AS (
    SELECT s.*,
           ROW_NUMBER() OVER (PARTITION BY account_id ORDER BY start_date DESC) AS rn
    FROM subscriptions s
)
SELECT plan_tier, SUM(mrr_amount) AS total_mrr, ROUND(AVG(mrr_amount), 2) AS avg_mrr, COUNT(*) AS n_accounts
FROM latest_sub
WHERE rn = 1
GROUP BY plan_tier
ORDER BY total_mrr DESC;

-- 2. Which industries have the highest average current MRR
WITH latest_sub AS (
    SELECT s.*,
           ROW_NUMBER() OVER (PARTITION BY account_id ORDER BY start_date DESC) AS rn
    FROM subscriptions s
)
SELECT a.industry,
       ROUND(AVG(l.mrr_amount), 2) AS avg_mrr,
       COUNT(*) AS n_accounts
FROM accounts a
JOIN latest_sub l ON a.account_id = l.account_id AND l.rn = 1
GROUP BY a.industry
ORDER BY avg_mrr DESC;

-- 3. Top 10 accounts by current MRR
-- WINDOW FUNCTION: RANK() so accounts with equal MRR share a rank
WITH latest_sub AS (
    SELECT s.*,
           ROW_NUMBER() OVER (PARTITION BY account_id ORDER BY start_date DESC) AS rn
    FROM subscriptions s
),
ranked_accounts AS (
    SELECT a.account_id, a.account_name, a.industry, l.plan_tier, l.mrr_amount,
           RANK() OVER (ORDER BY l.mrr_amount DESC) AS mrr_rank
    FROM accounts a
    JOIN latest_sub l ON a.account_id = l.account_id AND l.rn = 1
)
SELECT *
FROM ranked_accounts
WHERE mrr_rank <= 10
ORDER BY mrr_rank;

-- 4. Monthly new-subscription MRR booked, with a running (cumulative) total
-- DATE FUNCTION: strftime() extracts year-month from start_date.
-- WINDOW FUNCTION: SUM() OVER (ORDER BY ...) as a running total,
-- and LAG() to see the prior month for a simple month-over-month view.
WITH monthly AS (
    SELECT strftime('%Y-%m', start_date) AS start_month,
           SUM(mrr_amount) AS new_mrr_booked
    FROM subscriptions
    GROUP BY start_month
)
SELECT start_month,
       new_mrr_booked,
       SUM(new_mrr_booked) OVER (ORDER BY start_month) AS running_mrr_booked,
       LAG(new_mrr_booked) OVER (ORDER BY start_month) AS prev_month_mrr
FROM monthly
ORDER BY start_month;

-- 5. Accounts with MRR above the overall average MRR
-- SUBQUERY in the WHERE clause
WITH latest_sub AS (
    SELECT s.*,
           ROW_NUMBER() OVER (PARTITION BY account_id ORDER BY start_date DESC) AS rn
    FROM subscriptions s
)
SELECT a.account_id, a.account_name, l.plan_tier, l.mrr_amount
FROM accounts a
JOIN latest_sub l ON a.account_id = l.account_id AND l.rn = 1
WHERE l.mrr_amount > (
    SELECT AVG(mrr_amount) FROM latest_sub WHERE rn = 1
)
ORDER BY l.mrr_amount DESC;

-- 6. Revenue segmentation: Low / Medium / High MRR accounts
-- CASE WHEN used to bucket accounts into simple revenue tiers
WITH latest_sub AS (
    SELECT s.*,
           ROW_NUMBER() OVER (PARTITION BY account_id ORDER BY start_date DESC) AS rn
    FROM subscriptions s
)
SELECT
    CASE
        WHEN mrr_amount < 300 THEN 'Low MRR'
        WHEN mrr_amount BETWEEN 300 AND 1500 THEN 'Medium MRR'
        ELSE 'High MRR'
    END AS mrr_segment,
    COUNT(*) AS n_accounts,
    ROUND(AVG(mrr_amount), 2) AS avg_mrr
FROM latest_sub
WHERE rn = 1
GROUP BY mrr_segment
ORDER BY avg_mrr;

-- 7. Annual vs monthly billing: account count, average MRR, and upgrade/downgrade activity
-- CONDITIONAL AGGREGATION with CASE WHEN inside SUM()/AVG()
SELECT
    billing_frequency,
    COUNT(*) AS n_subscriptions,
    ROUND(AVG(mrr_amount), 2) AS avg_mrr,
    SUM(CASE WHEN upgrade_flag = 1 THEN 1 ELSE 0 END) AS n_upgrades,
    SUM(CASE WHEN downgrade_flag = 1 THEN 1 ELSE 0 END) AS n_downgrades
FROM subscriptions
GROUP BY billing_frequency;
