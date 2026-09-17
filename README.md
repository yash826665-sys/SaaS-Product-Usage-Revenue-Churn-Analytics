# SaaS-Product-Usage-Revenue-Churn-Analytics


### An End-to-End Data Analytics Project using SQL, Python, Statistics and Tableau


## Overview

This is a data analytics portfolio project built around a simulated B2B SaaS company, RavenStack. It walks through the full analytics workflow — data understanding, SQL analysis, Python EDA and Statistics, and Tableau dashboard design — to answer realistic product, revenue, and churn questions.

## Business Problem

RavenStack is preparing for broader product growth and wants to understand:
1. How customers are using the product
2. Which plans and customer groups generate more revenue
3. Which factors are associated with customer churn
4. Whether product usage and support experience differ between retained and churned customers

## Objectives

- Practice SQL (window functions, CTEs, joins, subqueries, conditional aggregation, date functions, CASE WHEN, basic optimization)
- Practice Python-based EDA and statistics (Pandas, NumPy, Matplotlib, Seaborn, SciPy)
- Practice statistical reasoning (descriptive stats, correlation, hypothesis testing, a hypothetical A/B test, and simple regression)
- Design a clean, business-usable Tableau dashboard
- Produce clear, interview-ready documentation of the whole process

## Dataset

Five CSV files describing RavenStack's (synthetic) customers:
- `ravenstack_accounts.csv` — 500 accounts
- `ravenstack_subscriptions.csv` — 5,000 subscription/billing period records
- `ravenstack_feature_usage.csv` — 25,000 feature usage events
- `ravenstack_support_tickets.csv` — 2,000 support tickets
- `ravenstack_churn_events.csv` — 600 churn events

See `DATA_DICTIONARY.md` for full column definitions and key relationships.

## Tools

| Category | Tools |
|---|---|
| SQL | Pgsql
| Python | pandas, numpy, matplotlib, seaborn, scipy |
| Statistics | descriptive statistics, correlation, t-tests, ANOVA, chi-square, simple linear regression |
| Visualization | Tableau (dashboard) |

## SQL Techniques Demonstrated

Window functions (`ROW_NUMBER`, `RANK`, `DENSE_RANK`, `LAG`, running `SUM() OVER`), CTEs (including multi-step CTE chains), joins across 3+ tables, subqueries, conditional aggregation (`SUM(CASE WHEN ...)`), date functions (`strftime`, `julianday`), `CASE WHEN` segmentation, and two basic query-optimization examples using `EXPLAIN QUERY PLAN`.

## Python Techniques Demonstrated

Data loading & cleaning, missing-value and duplicate checks, date conversion, derived columns, multi-table merges, descriptive statistics, a correlation heatmap, three hypothesis tests (t-tests + ANOVA) plus a chi-square test, a clearly-labeled **hypothetical** simulated A/B test, and two simple linear regressions.

## Tableau

1. **RavenStack Business Overview** — KPIs, MRR trend, revenue by plan, accounts by industry/referral source, churn by plan
2. **Product Usage & Customer Churn** — feature usage, usage by plan, usage vs MRR, churn by usage segment, churn reasons, support tickets vs churn

## Key Findings

1. RavenStack's current total MRR is **$1,257,903** across 500 accounts (avg. **$2,516**/account); revenue is heavily concentrated in Enterprise accounts (~77% of total MRR).
2. The overall account churn rate is **22.0%** (110 of 500 accounts).
3. MRR differs significantly across plan tiers (ANOVA, p < 0.001) — expected, but confirms pricing tiers are functioning as designed.
4. Churned and retained customers do **not** differ significantly in total product usage (Welch's t-test, p = 0.158) or average support satisfaction (p = 0.437). Churn does not appear to be a simple function of "low usage" or "bad support" in this dataset.
5. Churn is **not** significantly associated with plan tier (chi-square test, p = 0.788).
6. The widest churn-rate spreads are by **industry** (DevTools 31.0% vs. Cybersecurity 16.0%) and **referral source** (event-acquired accounts 30.2% vs. partner-referred accounts 14.6%).
7. Number of seats is a much stronger, statistically significant predictor of MRR (R² ≈ 0.186, p < 0.001) than product usage (R² ≈ 0.002, not significant).
8. Churn reasons are spread fairly evenly across features, support, and budget — there is no single dominant churn cause.

## Recommendations

See `RavenStack_Final_Report.pdf` (Section 18) for the full, finding-linked recommendations. In short: investigate the DevTools segment and event-sourced acquisition channel specifically, treat usage/satisfaction metrics as insufficient standalone churn predictors, and lean further into seat-based expansion as the primary revenue lever.

## Project Structure

```
RavenStack_Data_Analytics/
├── README.md
├── DATA_DICTIONARY.md
├── data/
│   ├── raw/            <- original, untouched CSVs
│   └── processed/      <- cleaned/merged master table
├── sql/                <- 01 through 06, ~40 queries total
├── python/             <- 3 Jupyter notebooks
├── tableau/            <- dashboard PNGs
├── report/             <- final PDF report
└── outputs/
    ├── charts/                 <- all EDA/statistical charts (PNG)
    └── statistical_results/    <- descriptive stats, test results, correlations (CSV/JSON)
```

## Limitations

- This is a **synthetic** dataset; patterns and relationships may not reflect a real SaaS business.
- `accounts.plan_tier` sometimes disagrees with the plan tier on an account's latest subscription — a data-quality quirk documented in `DATA_DICTIONARY.md` and handled by consistently using subscription-level plan data for revenue analysis.
- Several relationships tested here (usage vs. churn, satisfaction vs. churn) were **not** statistically significant — this is reported honestly rather than being dressed up as a finding.
- The A/B test section is a hypothetical, simulated example only — RavenStack's data does not contain a real experiment.
- Regression analysis here is simple bivariate regression for learning purposes, not a production pricing or churn model.

## Author's Note

This project was built as a learning exercise to practice SQL, Python, statistics, and Tableau on a realistic (synthetic) SaaS dataset.
