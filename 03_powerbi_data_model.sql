-- H&M Customer Growth & Retention Intelligence | DuckDB
-- 03 | Power BI reporting model
-- Run after 02_customer_growth_retention_analysis.sql.
-- Output CSVs are written to the DuckDB working directory.
-- Channel IDs are kept as codes; do not assume online vs. store.
-- Draft pending execution validation against the published dashboards.

CREATE OR REPLACE TABLE pbi_customer_snapshot AS

WITH future_activity AS (
    SELECT
        customer_id,
        COUNT(DISTINCT transaction_date) AS future_purchase_days,
        SUM(price) AS future_normalized_value
    FROM transactions
    WHERE transaction_date > DATE '2020-06-30'
      AND transaction_date <= DATE '2020-09-22'
    GROUP BY customer_id
)

SELECT
    s.customer_id,
    s.first_purchase_date,
    s.last_purchase_date,
    s.purchase_days,
    s.historical_value,
    s.days_since_last_purchase,
    s.recency_band,
    s.value_quartile,

    CASE
        WHEN f.customer_id IS NOT NULL THEN 1
        ELSE 0
    END AS returned_within_84_days,

    COALESCE(f.future_purchase_days, 0)
        AS future_purchase_days,

    COALESCE(f.future_normalized_value, 0)
        AS future_normalized_value

FROM customer_segments_june2020 s

LEFT JOIN future_activity f
    ON s.customer_id = f.customer_id;

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT customer_id) AS unique_customers,
    SUM(returned_within_84_days) AS returning_customers,
    ROUND(
        100.0 * SUM(returned_within_84_days) / COUNT(*),
        2
    ) AS overall_return_rate_pct,
    ROUND(SUM(historical_value), 2) AS total_historical_value,
    ROUND(SUM(future_normalized_value), 2) AS total_future_value
FROM pbi_customer_snapshot;

SELECT
    recency_band,
    value_quartile,
    COUNT(*) AS customers,
    SUM(returned_within_84_days) AS returning_customers,
    ROUND(
        100.0 * AVG(returned_within_84_days),
        2
    ) AS return_rate_pct,
    ROUND(
        100.0 * SUM(historical_value)
        / SUM(SUM(historical_value)) OVER (),
        2
    ) AS historical_value_share_pct
FROM pbi_customer_snapshot
GROUP BY recency_band, value_quartile
ORDER BY
    CASE recency_band
        WHEN '0-30 days' THEN 1
        WHEN '31-90 days' THEN 2
        WHEN '91-180 days' THEN 3
        ELSE 4
    END,
    value_quartile;

ALTER TABLE pbi_customer_snapshot
ADD COLUMN frequency_band VARCHAR;

UPDATE pbi_customer_snapshot
SET frequency_band =
    CASE
        WHEN purchase_days = 1 THEN '1 day'
        WHEN purchase_days BETWEEN 2 AND 3 THEN '2-3 days'
        WHEN purchase_days BETWEEN 4 AND 6 THEN '4-6 days'
        WHEN purchase_days BETWEEN 7 AND 12 THEN '7-12 days'
        WHEN purchase_days BETWEEN 13 AND 24 THEN '13-24 days'
        ELSE '25+ days'
    END;

SELECT
    frequency_band,
    COUNT(*) AS customers,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS customer_share_pct,
    MIN(purchase_days) AS min_purchase_days,
    MAX(purchase_days) AS max_purchase_days
FROM pbi_customer_snapshot
GROUP BY frequency_band
ORDER BY MIN(purchase_days);

CREATE OR REPLACE VIEW pbi_segment_summary AS

SELECT
    recency_band,
    value_quartile,
    COUNT(*) AS customers,
    SUM(historical_value) AS historical_normalized_value,
    SUM(returned_within_84_days) AS returning_customers,
    SUM(future_normalized_value) AS future_normalized_value,
    ROUND(
        100.0 * AVG(returned_within_84_days),
        2
    ) AS return_rate_pct,
    ROUND(
        SUM(future_normalized_value) / COUNT(*),
        4
    ) AS future_value_per_customer

FROM pbi_customer_snapshot

GROUP BY
    recency_band,
    value_quartile;

SELECT
    COUNT(*) AS total_segments,
    SUM(customers) AS total_customers,
    SUM(returning_customers) AS total_returning_customers,
    ROUND(SUM(historical_normalized_value), 2)
        AS total_historical_value,
    ROUND(SUM(future_normalized_value), 2)
        AS total_future_value
FROM pbi_segment_summary;

CREATE OR REPLACE TABLE pbi_customer_channel AS

SELECT
    customer_id,

    CASE
        WHEN COUNT(DISTINCT sales_channel_id) = 2
            THEN 'Both channels'
        WHEN MIN(sales_channel_id) = 1
            THEN 'Channel 1 only'
        WHEN MIN(sales_channel_id) = 2
            THEN 'Channel 2 only'
        ELSE 'Unknown'
    END AS channel_history

FROM transactions

WHERE transaction_date <= DATE '2020-06-30'

GROUP BY customer_id;

SELECT
    channel_history,
    COUNT(*) AS customers,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS customer_share_pct
FROM pbi_customer_channel
GROUP BY channel_history
ORDER BY
    CASE channel_history
        WHEN 'Both channels' THEN 1
        WHEN 'Channel 1 only' THEN 2
        WHEN 'Channel 2 only' THEN 3
        ELSE 4
    END;

CREATE OR REPLACE TABLE pbi_segment_product_profile AS

SELECT
    s.recency_band,
    s.value_quartile,
    a.product_group_name,

    COUNT(*) AS recorded_transaction_rows,

    COUNT(DISTINCT t.customer_id)
        AS purchasing_customers,

    SUM(t.price)
        AS historical_normalized_value

FROM transactions t

INNER JOIN pbi_customer_snapshot s
    ON t.customer_id = s.customer_id

INNER JOIN articles a
    ON t.article_id = a.article_id

WHERE t.transaction_date <= DATE '2020-06-30'

GROUP BY
    s.recency_band,
    s.value_quartile,
    a.product_group_name;

SELECT
    COUNT(*) AS profile_rows,
    COUNT(DISTINCT product_group_name) AS product_groups,
    SUM(recorded_transaction_rows) AS total_transaction_rows,
    ROUND(
        SUM(historical_normalized_value), 2
    ) AS total_historical_value
FROM pbi_segment_product_profile;

SELECT
    COUNT(*) AS snapshot_customers,
    COUNT(c.customer_id) AS matched_channel_customers,
    COUNT(*) - COUNT(c.customer_id) AS unmatched_customers,
    COUNT(DISTINCT c.customer_id) AS unique_matched_customers
FROM pbi_customer_snapshot s
LEFT JOIN pbi_customer_channel c
    ON s.customer_id = c.customer_id;

CREATE OR REPLACE VIEW pbi_customer_reporting AS
SELECT
    s.*,
    c.channel_history
FROM pbi_customer_snapshot s
LEFT JOIN pbi_customer_channel c
    ON s.customer_id = c.customer_id;

SELECT
    COUNT(*) AS total_customers,
    COUNT(DISTINCT customer_id) AS unique_customers,
    COUNT(*) FILTER (
        WHERE channel_history IS NULL
    ) AS missing_channel_history,
    SUM(returned_within_84_days) AS returning_customers,
    ROUND(SUM(historical_value), 2) AS historical_value,
    ROUND(SUM(future_normalized_value), 2) AS future_value
FROM pbi_customer_reporting;

COPY (
    SELECT *
    FROM pbi_customer_reporting
)
TO 'pbi_customer_reporting.csv'
(HEADER, DELIMITER ',');

COPY (
    SELECT *
    FROM pbi_segment_summary
)
TO 'pbi_segment_summary.csv'
(HEADER, DELIMITER ',');

COPY (
    SELECT *
    FROM pbi_segment_product_profile
)
TO 'pbi_segment_product_profile.csv'
(HEADER, DELIMITER ',');