/* ============================================================
   05_SUPPORT_ANALYSIS.SQL
   RavenStack SaaS Product, Revenue & Churn Analysis
   ------------------------------------------------------------
   Focus: support ticket volume, resolution speed, satisfaction,
   escalations, and how support experience compares between
   churned and retained accounts.
   ============================================================ */

-- 1. Ticket volume, resolution time, first response time and
--    satisfaction by priority
SELECT priority,
       COUNT(*) AS n_tickets,
       ROUND(AVG(resolution_time_hours), 1) AS avg_resolution_hours,
       ROUND(AVG(first_response_time_minutes), 1) AS avg_first_response_min,
       ROUND(AVG(satisfaction_score), 2) AS avg_satisfaction
FROM support_tickets
GROUP BY priority
ORDER BY avg_resolution_hours DESC;

-- 2. Escalation rate by priority
SELECT priority,
       SUM(CASE WHEN escalation_flag = 1 THEN 1 ELSE 0 END) AS n_escalations,
       COUNT(*) AS n_tickets,
       ROUND(100.0 * SUM(CASE WHEN escalation_flag = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS escalation_rate_pct
FROM support_tickets
GROUP BY priority
ORDER BY escalation_rate_pct DESC;

-- 3. Accounts with the most support tickets
-- WINDOW FUNCTION: RANK accounts by ticket volume
WITH ticket_counts AS (
    SELECT account_id, COUNT(*) AS n_tickets
    FROM support_tickets
    GROUP BY account_id
)
SELECT account_id, n_tickets,
       RANK() OVER (ORDER BY n_tickets DESC) AS ticket_rank
FROM ticket_counts
ORDER BY ticket_rank
LIMIT 10;

-- 4. Support experience: churned vs retained accounts
-- COMPLEX JOIN: accounts + support_tickets, aggregated per account then compared by churn status
WITH ticket_summary AS (
    SELECT account_id,
           COUNT(*) AS n_tickets,
           AVG(resolution_time_hours) AS avg_resolution_hours,
           AVG(satisfaction_score) AS avg_satisfaction,
           SUM(CASE WHEN escalation_flag = 1 THEN 1 ELSE 0 END) AS n_escalations
    FROM support_tickets
    GROUP BY account_id
)
SELECT
    CASE WHEN a.churn_flag = 1 THEN 'Churned' ELSE 'Retained' END AS status,
    COUNT(DISTINCT a.account_id) AS n_accounts,
    ROUND(AVG(t.n_tickets), 2) AS avg_tickets_per_account,
    ROUND(AVG(t.avg_resolution_hours), 1) AS avg_resolution_hours,
    ROUND(AVG(t.avg_satisfaction), 2) AS avg_satisfaction
FROM accounts a
LEFT JOIN ticket_summary t ON a.account_id = t.account_id
GROUP BY status;

-- 5. Accounts with an escalated ticket - do they churn more?
WITH escalated_accounts AS (
    SELECT DISTINCT account_id
    FROM support_tickets
    WHERE escalation_flag = 1
)
SELECT
    CASE WHEN e.account_id IS NOT NULL THEN 'Had escalation' ELSE 'No escalation' END AS escalation_status,
    COUNT(*) AS n_accounts,
    SUM(CASE WHEN a.churn_flag = 1 THEN 1 ELSE 0 END) AS n_churned,
    ROUND(100.0 * SUM(CASE WHEN a.churn_flag = 1 THEN 1 ELSE 0 END) / COUNT(*), 2) AS churn_rate_pct
FROM accounts a
LEFT JOIN escalated_accounts e ON a.account_id = e.account_id
GROUP BY escalation_status;

-- 6. Low satisfaction tickets (score <= 3) by priority
-- SUBQUERY used to first identify low-satisfaction tickets
SELECT priority, COUNT(*) AS n_low_satisfaction_tickets
FROM support_tickets
WHERE ticket_id IN (
    SELECT ticket_id FROM support_tickets WHERE satisfaction_score <= 3
)
GROUP BY priority
ORDER BY n_low_satisfaction_tickets DESC;
