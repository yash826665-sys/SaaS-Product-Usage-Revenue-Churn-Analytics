/* ============================================================
   03_PRODUCT_USAGE.SQL
   RavenStack SaaS Product, Revenue & Churn Analysis
   ------------------------------------------------------------
   Focus: how customers use the product - which features are
   popular, usage by plan, error rates, and beta adoption.
   ============================================================ */

-- 1. Most frequently used features (by total usage_count)
SELECT feature_name,
       SUM(usage_count) AS total_usage_count,
       COUNT(*) AS n_usage_events
FROM feature_usage
GROUP BY feature_name
ORDER BY total_usage_count DESC
LIMIT 10;

-- 2. Features with the highest error rate
-- CONDITIONAL AGGREGATION: errors as a share of usage events
SELECT feature_name,
       SUM(error_count) AS total_errors,
       COUNT(*) AS n_usage_events,
       ROUND(SUM(error_count) * 1.0 / COUNT(*), 3) AS avg_errors_per_event
FROM feature_usage
GROUP BY feature_name
ORDER BY avg_errors_per_event DESC
LIMIT 10;

-- 3. Beta feature adoption: how many accounts have tried a beta feature
-- COMPLEX JOIN: feature_usage -> subscriptions -> accounts (3 tables)
SELECT
    (SELECT COUNT(DISTINCT a.account_id)
     FROM feature_usage f
     JOIN subscriptions s ON f.subscription_id = s.subscription_id
     JOIN accounts a ON s.account_id = a.account_id
     WHERE f.is_beta_feature = 1) AS accounts_using_beta_features,
    (SELECT COUNT(DISTINCT account_id) FROM accounts) AS total_accounts;

-- 4. Product usage by plan tier
-- COMPLEX JOIN: feature_usage joined to subscriptions to bring in plan_tier,
-- needed because usage is only linked to a subscription, not directly to a plan.
SELECT s.plan_tier,
       ROUND(AVG(f.usage_count), 2) AS avg_usage_count,
       ROUND(AVG(f.usage_duration_secs), 1) AS avg_duration_secs,
       ROUND(AVG(f.error_count), 3) AS avg_error_count
FROM feature_usage f
JOIN subscriptions s ON f.subscription_id = s.subscription_id
GROUP BY s.plan_tier
ORDER BY avg_usage_count DESC;

-- 5. Per-account usage summary and Low/Medium/High usage segmentation
-- CTE chain: aggregate usage at the subscription level first, then roll
-- up to account level, then bucket with CASE WHEN.
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
    CASE
        WHEN account_total_usage <= 400 THEN 'Low'
        WHEN account_total_usage <= 550 THEN 'Medium'
        ELSE 'High'
    END AS usage_segment,
    COUNT(*) AS n_accounts,
    ROUND(AVG(account_total_usage), 1) AS avg_usage
FROM usage_by_account
GROUP BY usage_segment
ORDER BY avg_usage;

-- 6. Monthly usage trend (total usage_count per month)
SELECT strftime('%Y-%m', usage_date) AS usage_month,
       SUM(usage_count) AS total_usage_count,
       COUNT(*) AS n_usage_events
FROM feature_usage
GROUP BY usage_month
ORDER BY usage_month;
