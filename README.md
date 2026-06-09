# Automated B2B Sales Pipeline & Commercial Performance Analysis

> **End-to-End ELT Pipeline & BI Dashboard** — Google BigQuery + Looker Studio  
> Designed for commercial operations in a global industrial and services environment.

Looker Studio Link: https://datastudio.google.com/reporting/b9cb5173-be09-42b1-924f-cf82a02cab27
Pipeline:
<img width="913" height="646" alt="image" src="https://github.com/user-attachments/assets/4af7c670-4c1d-411b-9de2-ef023109fa4d" />

---

## Overview

In a global B2B environment, reliable decision-making depends on transforming raw CRM data into clean, trusted operational metrics — fast.

This project delivers an automated **two-layer data warehouse pipeline** on **Google BigQuery** that ingests transactional sales data, enforces automated data quality governance, and surfaces key commercial KPIs through an interactive **Looker Studio** executive dashboard.

---

## Tech Stack

![BigQuery](https://img.shields.io/badge/Google_BigQuery-4285F4?style=flat&logo=googlebigquery&logoColor=white)
![Looker Studio](https://img.shields.io/badge/Looker_Studio-4285F4?style=flat&logo=google&logoColor=white)
![SQL](https://img.shields.io/badge/SQL-Advanced-informational?style=flat)
<img width="913" height="646" alt="image" src="https://github.com/user-attachments/assets/bd0a06b3-3882-4706-819e-fd96c1a54acf" />

- **Google BigQuery** — Data warehouse, scheduled queries, window functions
- **Looker Studio** — BI visualization, real-time stakeholder dashboards
- **SQL** — CTEs, `RANK() OVER`, `DATE_DIFF`, conditional aggregation, compliance filtering
- **ELT Architecture** — Two-layer pipeline with separation of audit and business logic

---


### Business Value Delivered

| Outcome | How |
|---|---|
| **Revenue Forecasting Visibility** | Standardized open pipeline stages to calculate risk-adjusted predicted revenue, enabling strategic resource allocation |
| **Operational Efficiency Tracking** | Introduced `pipeline_velocity` metric to surface data latency and stalled long-standing deals |
| **Automated Data Quality Governance** | Programmatic audit system flags critical CRM entry errors (negative values, misaligned win probabilities), protecting downstream reporting integrity |

---

## Architecture — ELT Pipeline

The pipeline follows a scalable **Extract → Load → Transform** framework, decoupling ingestion, quality auditing, and business aggregation into independent layers.

```
┌─────────────────┐     ┌──────────────────────────┐     ┌─────────────────────────┐     ┌───────────────────────┐
│  Phase 1        │     │  Phase 2                 │     │  Phase 3                │     │  Phase 4              │
│  INGESTION      │────▶│  AUDIT & CLEANSE (L1)    │────▶│  AGGREGATION (L2)       │────▶│  BI REPORTING         │
│                 │     │                          │     │                         │     │                       │
│  Front-line CRM │     │  BigQuery View           │     │  BigQuery Table         │     │  Looker Studio        │
│  Nightly Sync   │     │  Data Quality Audit      │     │  Daily Scheduled Query  │     │  Real-time Dashboard  │
│  raw.B2B_sales  │     │  pipeline_qa_alert       │     │  performance (datamart) │     │  Stakeholder Reports  │
└─────────────────┘     └──────────────────────────┘     └─────────────────────────┘     └───────────────────────┘
```

**Phase 1 — Ingestion:** Front-line sales managers log deals into the CRM across global geographies. Every midnight, an ETL sync lands these rows into the raw BigQuery table `B2B_sales`.

**Phase 2 — Transformation & Audit (Layer 1 View):** The `pipeline_qa_alert` view processes 100% of raw data — standardizing fields, computing lead-to-close timelines, and appending a `Data_Quality_Flag` using conditional logic to isolate corrupt records without deleting historical lineage.

**Phase 3 — Data Mart Materialization (Layer 2 Table):** A BigQuery Scheduled Query runs daily at 06:00 AM. It filters financial anomalies, aggregates metrics using CTEs, and applies window functions to generate final commercial KPIs in the `performance` table.

**Phase 4 — BI Consumption:** Looker Studio connects directly to both pipeline layers, providing real-time data exploration tailored for business stakeholders.

---

## Project Structure

```
BigQuery Project/
│
└── Dataset: commercial_services/
    │
    ├── Tables/
    │   ├── B2B_sales                  # Raw landing table — nightly CRM sync
    │   └── performance                # Layer 2: Curated reporting datamart
    │
    └── Views/
        └── pipeline_qa_alert          # Layer 1: Staging, audit & data quality
```

---

## SQL Implementation

### Layer 1 — Staging View: Data Quality Audit (`pipeline_qa_alert`)

**Objective:** Audit CRM entry conformity, compute timeline metrics, and preserve data lineage without destructive filtering.

```sql
CREATE OR REPLACE VIEW `project.dataset.pipeline_qa_alert` AS
SELECT 
    organization          AS account_name,
    country,
    latitude,
    longitude,
    industry,
    organization_size,
    owner,
    product,
    status,
    stage,
    deal_value,
    ROUND(probability / 100, 2) AS probability_rate,
    lead_acquisition_date,
    expected_close_date,
    actual_close_date,

    -- Pipeline Velocity: Days from lead acquisition to expected close
    DATE_DIFF(expected_close_date, lead_acquisition_date, DAY) AS pipeline_velocity,

    -- Automated Data Quality Compliance Engine
    CASE
        WHEN deal_value < 0
            THEN 'ERROR: Negative Deal Value'
        WHEN stage = 'Lost' AND probability > 0
            THEN 'ERROR: Lost Deal with Positive Probability'
        WHEN stage IN ('Proposal sent', 'Opened') AND expected_close_date < CURRENT_DATE()
            THEN 'WARNING: Overdue Expected Close Date'
        ELSE 'PASS'
    END AS Data_Quality_Flag

FROM `project.dataset.B2B_sales`;
```

**Key design decisions:**
- Non-destructive flagging — corrupt records are isolated, not deleted, preserving full data lineage for audit trails
- `pipeline_velocity` surfaces stalled deals for operational review
- `probability_rate` normalizes CRM percentage inputs for downstream aggregation

---

### Layer 2 — Business Intelligence Datamart (`performance`)

**Objective:** Aggregate clean business metrics, enforce compliance filtering, and rank geographical sales performance.

```sql
CREATE OR REPLACE TABLE `project.dataset.performance` AS

WITH industry_metrics AS (
    SELECT 
        industry, 
        country,
        owner AS sales_rep_name,

        -- Closed Won: Actual realized revenue
        SUM(CASE WHEN stage = 'Won' THEN deal_value ELSE 0 END)                                       AS closed_won_revenue,

        -- Predicted Revenue: Risk-adjusted open pipeline forecast
        SUM(CASE WHEN stage NOT IN ('Won', 'Lost') THEN deal_value * probability_rate ELSE 0 END)     AS predicted_revenue,

        SUM(CASE WHEN stage = 'Won' THEN 1 ELSE 0 END)                                                AS won_deals_count,
        COUNT(*)                                                                                        AS total_deals

    FROM `project.dataset.pipeline_qa_alert`
    WHERE Data_Quality_Flag != 'ERROR: Negative Deal Value'   -- Compliance filter: exclude financial anomalies
    GROUP BY industry, country, sales_rep_name
)

SELECT 
    industry,
    country,
    sales_rep_name,
    closed_won_revenue,
    ROUND(predicted_revenue, 2)                                                    AS predicted_revenue,
    total_deals,
    ROUND(won_deals_count / total_deals * 100, 2)                                  AS win_rate_percentage,

    -- Geographic ranking: Sales rep performance within each regional market
    RANK() OVER (PARTITION BY country ORDER BY closed_won_revenue DESC)            AS rep_rank_in_country

FROM industry_metrics;
```

**Key design decisions:**
- CTE structure separates aggregation logic from ranking, improving readability and maintainability
- `RANK() OVER (PARTITION BY country)` enables regional leaderboards without additional post-processing
- Compliance filter applied at the datamart layer — not in Layer 1 — to preserve complete audit visibility upstream

---

## BI Dashboard — Looker Studio
Looker Studio Link: https://datastudio.google.com/reporting/b9cb5173-be09-42b1-924f-cf82a02cab27
<img width="1323" height="996" alt="image" src="https://github.com/user-attachments/assets/5cc4d59e-88be-4129-8194-18ca78b51a2d" />


Both pipeline layers feed dynamically into an executive Looker Studio dashboard built for non-technical stakeholders.

| Dashboard Component | Data Source | Purpose |
|---|---|---|
| **Executive Scorecards** | Layer 2 — `performance` | Global `Closed Won Revenue` and `Predicted Revenue` at a glance |
| **Sales Rep Leaderboard** | Layer 2 — `performance` | `RANK() OVER` drives regional win rate rankings across geographic markets |
| **Product Penetration Grid** | Layer 1 — `pipeline_qa_alert` | Cross-sectional view of product uptake by organization size (Enterprise vs. SME) — reveals upsell potential |
| **Data Quality Monitor** | Layer 1 — `pipeline_qa_alert` | Live breakdown of `Data_Quality_Flag` anomalies (`ERROR`, `WARNING`, `PASS`) — equips ops teams with a data-cleansing action list |

---

## Pipeline Automation


| Step | Mechanism | Schedule |
|---|---|---|
| Raw data ingestion | CRM → BigQuery ETL integration | Nightly |
| Layer 2 materialization | BigQuery Scheduled Query | Daily at 06:00 AM |
| Dashboard refresh | Looker Studio automated cache refresh | Morning, pre-business hours |

Stakeholders receive updated commercial insights at the start of each business day with zero manual intervention.

---

## Key Skills Demonstrated

- Designing scalable **multi-layer ELT pipelines** on cloud data warehouses
- Writing production-quality **BigQuery SQL** with CTEs and analytical window functions
- Building **automated data quality governance** without disrupting data lineage
- Translating raw CRM data into **business-ready KPIs** (Win Rate %, Predicted Revenue, Pipeline Velocity)
- Delivering **BI dashboards** optimized for non-technical commercial stakeholders
