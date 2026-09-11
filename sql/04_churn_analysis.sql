/* ============================================================
   04_CHURN_ANALYSIS.SQL
   RavenStack SaaS Product, Revenue & Churn Analysis
   ------------------------------------------------------------
   Focus: churn rate by segment, churn reasons, and whether
   usage/support patterns differ between churned and retained
   customers. accounts.churn_flag is treated as the account's
   current status (source of truth for this analysis).
   ============================================================ */

-- 1. Churn rate by plan tier
-- COMPLEX JOIN: accounts joined to latest subscription for plan_tier
WITH latest_sub AS (
    SELECT s.*, ROW_NUMBER() OVER (PARTITION BY account_id ORDER BY start_date DESC) AS rn
    FROM subscriptions s
)
SELECT l.plan_tier,
       COUNT(*) AS n_accounts,
       SUM(CASE WHEN a.churn_flag = 1 THEN 1 ELSE 0 END) AS n_churned,
       ROUND(100.0 * SUM(CASE WHEN a.churn_flag = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS churn_rate_pct
FROM accounts a
JOIN latest_sub l ON a.account_id = l.account_id AND l.rn = 1
GROUP BY l.plan_tier
ORDER BY churn_rate_pct DESC;

-- 2. Churn rate by industry and by referral source
SELECT 'industry' AS dimension, industry AS value,
       COUNT(*) AS n_accounts,
       ROUND(100.0 * SUM(CASE WHEN churn_flag = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS churn_rate_pct
FROM accounts
GROUP BY industry
UNION ALL
SELECT 'referral_source' AS dimension, referral_source AS value,
       COUNT(*) AS n_accounts,
       ROUND(100.0 * SUM(CASE WHEN churn_flag = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS churn_rate_pct
FROM accounts
GROUP BY referral_source
ORDER BY dimension, churn_rate_pct DESC;

-- 3. Most common churn reasons
SELECT reason_code, COUNT(*) AS n_events,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM churn_events), 1) AS pct_of_churn_events
FROM churn_events
GROUP BY reason_code
ORDER BY n_events DESC;

-- 4. Average time from signup to churn (days)
-- COMPLEX JOIN + DATE FUNCTION: accounts joined to churn_events,
-- julianday() difference gives customer lifetime in days
SELECT ROUND(AVG(julianday(c.churn_date) - julianday(a.signup_date)), 1) AS avg_days_to_churn,
       COUNT(*) AS n_churn_events
FROM churn_events c
JOIN accounts a ON c.account_id = a.account_id;

-- 5. Do churned customers have lower product usage than retained customers?
-- CTE chain: usage per account -> compare average usage by churn status
WITH usage_by_sub AS (
    SELECT subscription_id, SUM(usage_count) AS total_usage_count
    FROM feature_usage
    GROUP BY subscription_id
),
usage_by_account AS (
    SELECT s.account_id, SUM(u.total_usage_count) AS account_total_usage
    FROM usage_by_sub u
    JOIN subscriptions s ON u.subscription_id = s.subscription_id
    GROUP BY s.account_id
)
SELECT
    CASE WHEN a.churn_flag = 1 THEN 'Churned' ELSE 'Retained' END AS status,
    COUNT(*) AS n_accounts,
    ROUND(AVG(ua.account_total_usage), 1) AS avg_total_usage
FROM accounts a
LEFT JOIN usage_by_account ua ON a.account_id = ua.account_id
GROUP BY status;

-- 6. Do customers with more support tickets churn more often?
-- COMPLEX JOIN: accounts + support_tickets, conditional aggregation to bucket ticket volume
WITH ticket_counts AS (
    SELECT account_id, COUNT(*) AS n_tickets
    FROM support_tickets
    GROUP BY account_id
)
SELECT
    CASE
        WHEN COALESCE(t.n_tickets, 0) = 0 THEN '0 tickets'
        WHEN t.n_tickets BETWEEN 1 AND 3 THEN '1-3 tickets'
        WHEN t.n_tickets BETWEEN 4 AND 6 THEN '4-6 tickets'
        ELSE '7+ tickets'
    END AS ticket_bucket,
    COUNT(*) AS n_accounts,
    SUM(CASE WHEN a.churn_flag = 1 THEN 1 ELSE 0 END) AS n_churned,
    ROUND(100.0 * SUM(CASE WHEN a.churn_flag = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS churn_rate_pct
FROM accounts a
LEFT JOIN ticket_counts t ON a.account_id = t.account_id
GROUP BY ticket_bucket
ORDER BY churn_rate_pct DESC;

-- 7. Churn events over time (monthly) and overall reactivation rate
SELECT strftime('%Y-%m', churn_date) AS churn_month,
       COUNT(*) AS n_churn_events,
       SUM(CASE WHEN is_reactivation = 1 THEN 1 ELSE 0 END) AS n_reactivations
FROM churn_events
GROUP BY churn_month
ORDER BY churn_month;
