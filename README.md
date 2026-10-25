# H&M Customer Growth & Retention Intelligence

A SQL and Power BI portfolio case study exploring customer purchase behavior, historical value concentration, and observed 84-day return patterns in the public H&M Personalized Fashion Recommendations dataset.

## Business questions

- How is the purchasing customer base distributed by recency and frequency?
- How concentrated is historical normalized purchase value?
- Which recency–value segments show stronger observed future return?
- Which product groups have the broadest purchasing customer reach?

## Key findings

- **1,298,206** customers made at least one recorded purchase on or before June 30, 2020.
- **43.79%** had no recorded purchase in the preceding 180 days.
- The highest historical-value quartile contributed approximately **75.13%** of historical normalized value.
- **425,478** customers (**32.77%**) made a recorded purchase during the subsequent 84 days.
- The most recent, highest-value segment had a **78.95%** observed return rate; the 181+ day, lowest-value segment had **6.58%**.

## Dashboard pages

- Customer Portfolio Overview — recency, frequency, channel history, and value concentration.
- Customer Behaviour & Segmentation — product group reach, segment distribution, historical value, and observed return.

Screenshots: [Customer Portfolio Overview](Customer_Portfolio_Overview.png) · [Customer Behaviour & Segmentation](Customer_Behaviour_Segmentation.png)

## SQL scripts

Run in this order (using DuckDB):

1. [`01_data_quality_audit.sql`](sql/01_data_quality_audit.sql): checks source quality, missing values, key coverage, and duplicate-looking rows.
2. [`02_customer_growth_retention_analysis.sql`](sql/02_customer_growth_retention_analysis.sql): loads the dataset, builds a June 2020 customer snapshot, and analyzes observed return by recency and value.
3. [`03_powerbi_data_model.sql`](sql/03_powerbi_data_model.sql): creates customer and segment reporting tables and exports CSVs for Power BI.

Download `transactions_train.csv`, `customers.csv`, and `articles.csv` from the [H&M Personalized Fashion Recommendations Kaggle dataset](https://www.kaggle.com/competitions/h-and-m-personalized-fashion-recommendations/data). Place them in the DuckDB working directory or update the local paths. The raw files are not included in this repository. The source dataset is large and some SQL steps may use substantial memory.

## Method and limitations

The analysis uses a **June 30, 2020** customer snapshot and checks for subsequent purchases from **July 1 to September 22, 2020**, inclusive (84 days). Recency is measured at the snapshot date. Historical value quartiles are ranked across the entire purchasing-customer population. Purchase frequency counts **distinct purchase dates**, not orders. Prices are **normalized**, so values must not be interpreted as dollars or actual revenue. Sales-channel identifiers are treated as codes because channel labels are not established. Observed return does not prove churn or the effect of a marketing intervention. Identical transaction rows are not automatically removed because they may represent multiple units.

**Validation status:** SQL scripts have been cleaned and organized, but the final published versions have **not yet been fully rerun and reconciled** with the Power BI dashboards. Any discrepancies found during validation will be corrected in subsequent commits.
