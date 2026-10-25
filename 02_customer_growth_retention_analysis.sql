-- H&M Customer Growth & Retention Intelligence | DuckDB
-- 02 | Customer growth and retention analysis
-- Snapshot: 2020-06-30 | Outcome window: 2020-07-01 to 2020-09-22 (84 days).
-- Prices are normalized values, NOT currency-denominated revenue.
-- Distinct purchase dates are not equivalent to orders.
-- Identical transaction rows are retained; they may represent multiple units.


-- A. Load typed source tables (large import; run only when needed)
CREATE OR REPLACE TABLE transactions AS
SELECT
    CAST(t_dat AS DATE) AS transaction_date,
    customer_id,
    article_id,
    CAST(price AS DOUBLE) AS price,
    CAST(sales_channel_id AS INTEGER) AS sales_channel_id
FROM read_csv(
    'transactions_train.csv',
    all_varchar = true
);

CREATE OR REPLACE TABLE customers AS
SELECT
    customer_id,
    CAST(FN AS INTEGER) AS fn,
    CAST(Active AS INTEGER) AS active,
    club_member_status,
    fashion_news_frequency,
    TRY_CAST(age AS INTEGER) AS age,
    postal_code
FROM read_csv(
    'customers.csv',
    all_varchar = true
);

CREATE OR REPLACE TABLE articles AS
SELECT *
FROM read_csv(
    'articles.csv',
    all_varchar = true
);


-- B. Build the historical purchasing customer universe and value quartiles
CREATE OR REPLACE TABLE customer_segments_june2020 AS

WITH customer_snapshot AS (
    SELECT
        customer_id,
        MIN(transaction_date) AS first_purchase_date,
        MAX(transaction_date) AS last_purchase_date,
        COUNT(DISTINCT transaction_date) AS purchase_days,
        SUM(price) AS historical_value
    FROM transactions
    WHERE transaction_date <= DATE '2020-06-30'
    GROUP BY customer_id
)

SELECT
    customer_id,
    first_purchase_date,
    last_purchase_date,
    purchase_days,
    historical_value,

    DATE_DIFF(
        'day',
        last_purchase_date,
        DATE '2020-06-30'
    ) AS days_since_last_purchase,

    CASE
        WHEN DATE_DIFF('day', last_purchase_date, DATE '2020-06-30') <= 30
            THEN '0-30 days'
        WHEN DATE_DIFF('day', last_purchase_date, DATE '2020-06-30') <= 90
            THEN '31-90 days'
        WHEN DATE_DIFF('day', last_purchase_date, DATE '2020-06-30') <= 180
            THEN '91-180 days'
        ELSE '181+ days'
    END AS recency_band,

    NTILE(4) OVER (
        ORDER BY historical_value, customer_id
    ) AS value_quartile

FROM customer_snapshot;


-- C. Segment-level observed future return and normalized value
WITH future_activity AS (
    SELECT
        customer_id,
        COUNT(DISTINCT transaction_date) AS future_purchase_days,
        SUM(price) AS future_value
    FROM transactions
    WHERE transaction_date > DATE '2020-06-30'
      AND transaction_date <= DATE '2020-09-22'
    GROUP BY customer_id
)

SELECT
    s.recency_band,
    s.value_quartile,
    COUNT(*) AS customers,

    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        2
    ) AS customer_share_pct,

    ROUND(SUM(s.historical_value), 2)
        AS historical_normalized_value,

    ROUND(
        100.0 * SUM(s.historical_value)
        / SUM(SUM(s.historical_value)) OVER (),
        2
    ) AS historical_value_share_pct,

    COUNT(f.customer_id) AS returning_customers,

    ROUND(
        100.0 * COUNT(f.customer_id) / COUNT(*),
        2
    ) AS return_rate_pct,

    ROUND(
        COALESCE(SUM(f.future_value), 0), 2
    ) AS future_normalized_value,

    ROUND(
        COALESCE(SUM(f.future_value), 0) / COUNT(*),
        4
    ) AS future_value_per_customer

FROM customer_segments_june2020 s
LEFT JOIN future_activity f
    ON s.customer_id = f.customer_id

GROUP BY
    s.recency_band,
    s.value_quartile

ORDER BY
    CASE s.recency_band
        WHEN '0-30 days' THEN 1
        WHEN '31-90 days' THEN 2
        WHEN '91-180 days' THEN 3
        ELSE 4
    END,
    s.value_quartile;
