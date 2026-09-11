# Data Dictionary — RavenStack SaaS Dataset

RavenStack is a **fully synthetic** SaaS dataset created by **River @ Rivalytics**, used here purely for analytics practice. No real company, customers, or transactions are represented.

## 1. `accounts` (500 rows — one row per customer account)

| Column | Type | Description |
|---|---|---|
| `account_id` | string (PK) | Unique identifier for the account |
| `account_name` | string | Synthetic company name |
| `industry` | string | Industry category (Cybersecurity, DevTools, EdTech, FinTech, HealthTech) |
| `country` | string | Account's country (US, UK, IN, and others) |
| `signup_date` | date | Date the account signed up |
| `referral_source` | string | How the account was acquired (organic, ads, partner, event, other) |
| `plan_tier` | string | Account-level plan attribute (Basic / Pro / Enterprise) — see note below |
| `seats` | integer | Number of seats/licenses on the account |
| `is_trial` | boolean | Whether the account is currently on a trial |
| `churn_flag` | boolean | Whether the account's **current status** is churned. Used as the source of truth for churn analysis throughout this project. |

> **Data note:** `accounts.plan_tier` does not always match the `plan_tier` recorded on that account's most recent subscription record. This is a known quirk of the synthetic data. Throughout this project, whenever we discuss **revenue by plan**, we use the plan tier from the subscriptions table (since MRR is a subscription-level fact); whenever we discuss general account attributes, we use the accounts table.

## 2. `subscriptions` (5,000 rows — a history of subscription/billing periods per account, ~10 per account)

| Column | Type | Description |
|---|---|---|
| `subscription_id` | string (PK) | Unique identifier for the subscription record |
| `account_id` | string (FK → accounts) | Owning account |
| `start_date` | date | Subscription period start date |
| `end_date` | date (nullable) | Subscription period end date; `NULL` = still ongoing |
| `plan_tier` | string | Plan tier for this specific subscription period |
| `seats` | integer | Seats on this subscription record |
| `mrr_amount` | integer (USD) | Monthly recurring revenue for this subscription |
| `arr_amount` | integer (USD) | Annual recurring revenue for this subscription |
| `is_trial` | boolean | Whether this subscription period was a trial |
| `upgrade_flag` | boolean | Whether this record represents an upgrade |
| `downgrade_flag` | boolean | Whether this record represents a downgrade |
| `churn_flag` | boolean | Whether this specific subscription record ended in churn |
| `billing_frequency` | string | monthly / annual |
| `auto_renew_flag` | boolean | Whether auto-renewal is enabled |

**Derived rule used throughout this project:** an account's *current* subscription = the row with the latest `start_date` for that `account_id` (ties broken by `subscription_id`). This is used to calculate each account's current MRR, current plan, and current billing settings.

## 3. `feature_usage` (25,000 rows — one row per usage event)

| Column | Type | Description |
|---|---|---|
| `usage_id` | string (PK) | Unique identifier for the usage event |
| `subscription_id` | string (FK → subscriptions) | Related subscription |
| `usage_date` | date | Date of the usage event |
| `feature_name` | string | Feature used (e.g. `feature_2`, `feature_32`, ...) |
| `usage_count` | integer | Number of times the feature was used that day |
| `usage_duration_secs` | integer | Time spent using the feature, in seconds |
| `error_count` | integer | Number of errors encountered |
| `is_beta_feature` | boolean | Whether the feature is a beta feature |

## 4. `support_tickets` (2,000 rows — one row per support ticket)

| Column | Type | Description |
|---|---|---|
| `ticket_id` | string (PK) | Unique identifier for the ticket |
| `account_id` | string (FK → accounts) | Account that submitted the ticket |
| `submitted_at` | datetime | When the ticket was submitted |
| `closed_at` | datetime | When the ticket was closed |
| `resolution_time_hours` | float | Hours between submission and resolution |
| `priority` | string | low / medium / high / urgent |
| `first_response_time_minutes` | integer | Minutes until first response |
| `satisfaction_score` | float, 1-5 (nullable) | Customer satisfaction rating; `NULL` if no survey response given |
| `escalation_flag` | boolean | Whether the ticket was escalated |

## 5. `churn_events` (600 rows — a log of churn occurrences; can include reactivated accounts)

| Column | Type | Description |
|---|---|---|
| `churn_event_id` | string (PK) | Unique identifier for the churn event |
| `account_id` | string (FK → accounts) | Account that churned |
| `churn_date` | date | Date the churn event was logged |
| `reason_code` | string | features / support / budget / competitor / pricing / unknown |
| `refund_amount_usd` | float | Refund issued, if any |
| `preceding_upgrade_flag` | boolean | Whether the account had upgraded shortly before churning |
| `preceding_downgrade_flag` | boolean | Whether the account had downgraded shortly before churning |
| `is_reactivation` | boolean | Whether this event corresponds to an account that later reactivated |
| `feedback_text` | string (nullable) | Free-text churn feedback, if provided |

## Derived Metrics Used in This Project

| Metric | Definition |
|---|---|
| `current_plan_tier`, `mrr_amount` (account-level) | Taken from each account's latest subscription record (max `start_date`) |
| `total_usage_count`, `total_usage_duration_secs`, `total_error_count` | Sum of `feature_usage` fields, rolled up from subscription → account level |
| `n_features_used` | Count of distinct `feature_name` values used by the account |
| `n_tickets`, `avg_resolution_hours`, `avg_satisfaction`, `n_escalations` | Aggregated from `support_tickets`, grouped by `account_id` |
| `usage_segment` | Low / Medium / High, based on tertiles of `total_usage_count` |
| `mrr_segment` | Low / Medium / High MRR, based on tertiles of `mrr_amount` |
| `account_size` | Small (≤10 seats) / Medium (11-25 seats) / Large (26+ seats) |
| `status` | "Churned" if `accounts.churn_flag` is True, else "Retained" |
