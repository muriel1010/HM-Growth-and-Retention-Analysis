-- H&M Customer Growth & Retention Intelligence
-- 01 | Data quality audit (DuckDB)
-- Source: H&M Personalized Fashion Recommendations dataset.
-- Run from a directory containing transactions_train.csv, customers.csv, articles.csv,
-- or replace the relative paths below with your own local locations.
-- Read source columns as text for reliable validation before type conversion.
-- This script is read-only: it does not modify or deduplicate source data.

-- 1. Source volume, customer IDs, date validity, and price validity
WITH tx AS (
    SELECT *, TRY_CAST(t_dat AS DATE) AS parsed_date,
           TRY_CAST(price AS DOUBLE) AS numeric_price
    FROM read_csv('transactions_train.csv', all_varchar = true)
)
SELECT COUNT(*) AS transaction_rows,
       COUNT(DISTINCT customer_id) AS distinct_purchasing_customers,
       COUNT(*) FILTER (WHERE customer_id IS NULL OR TRIM(customer_id) = '') AS missing_customer_ids,
       COUNT(*) FILTER (WHERE parsed_date IS NULL) AS invalid_or_missing_dates,
       MIN(parsed_date) AS first_transaction_date,
       MAX(parsed_date) AS last_transaction_date,
       COUNT(*) FILTER (WHERE numeric_price IS NULL) AS invalid_or_missing_prices,
       COUNT(*) FILTER (WHERE numeric_price = 0) AS zero_prices,
       COUNT(*) FILTER (WHERE numeric_price < 0) AS negative_prices,
       MIN(numeric_price) AS min_price,
       MAX(numeric_price) AS max_price
FROM tx;

-- 2. Customer dimension: key integrity and field completeness
SELECT COUNT(*) AS customer_rows,
       COUNT(DISTINCT customer_id) AS unique_customer_ids,
       COUNT(*) - COUNT(DISTINCT customer_id) AS duplicate_id_rows,
       COUNT(*) FILTER (WHERE customer_id IS NULL OR TRIM(customer_id) = '') AS missing_customer_ids,
       COUNT(*) FILTER (WHERE age IS NULL OR TRIM(age) = '') AS missing_age,
       COUNT(*) FILTER (WHERE club_member_status IS NULL OR TRIM(club_member_status) = '') AS missing_club_status,
       COUNT(*) FILTER (WHERE fashion_news_frequency IS NULL OR TRIM(fashion_news_frequency) = '') AS missing_news_frequency,
       COUNT(*) FILTER (WHERE postal_code IS NULL OR TRIM(postal_code) = '') AS missing_postal_code,
       COUNT(*) FILTER (WHERE FN IS NULL OR TRIM(FN) = '') AS missing_fn,
       COUNT(*) FILTER (WHERE Active IS NULL OR TRIM(Active) = '') AS missing_active
FROM read_csv('customers.csv', all_varchar = true);

-- 3. Article dimension: key integrity
SELECT COUNT(*) AS article_rows,
       COUNT(DISTINCT article_id) AS unique_article_ids,
       COUNT(*) - COUNT(DISTINCT article_id) AS duplicate_id_rows,
       COUNT(*) FILTER (WHERE article_id IS NULL OR TRIM(article_id) = '') AS missing_article_ids
FROM read_csv('articles.csv', all_varchar = true);

-- 4. Foreign-key coverage: transaction customers and articles
WITH transaction_customers AS (
    SELECT DISTINCT customer_id FROM read_csv('transactions_train.csv', all_varchar = true)
), customer_dimension AS (
    SELECT DISTINCT customer_id FROM read_csv('customers.csv', all_varchar = true)
)
SELECT COUNT(*) AS purchasing_customers,
       COUNT(*) FILTER (WHERE c.customer_id IS NULL) AS unmatched_customers,
       ROUND(100.0 * COUNT(*) FILTER (WHERE c.customer_id IS NULL)
             / NULLIF(COUNT(*), 0), 2) AS unmatched_pct
FROM transaction_customers t
LEFT JOIN customer_dimension c USING (customer_id);

WITH purchased_articles AS (
    SELECT DISTINCT article_id FROM read_csv('transactions_train.csv', all_varchar = true)
), article_dimension AS (
    SELECT DISTINCT article_id FROM read_csv('articles.csv', all_varchar = true)
)
SELECT COUNT(*) AS purchased_article_ids,
       COUNT(*) FILTER (WHERE a.article_id IS NULL) AS unmatched_article_ids,
       ROUND(100.0 * COUNT(*) FILTER (WHERE a.article_id IS NULL)
             / NULLIF(COUNT(*), 0), 2) AS unmatched_pct
FROM purchased_articles p
LEFT JOIN article_dimension a USING (article_id);

-- 5. Identical transaction-row patterns
-- Identical records may represent multiple units purchased, not necessarily errors.
-- Do NOT delete identical rows automatically; doing so changes value totals.
WITH grouped AS (
    SELECT t_dat, customer_id, article_id, price, sales_channel_id,
           COUNT(*) AS row_count
    FROM read_csv('transactions_train.csv', all_varchar = true)
    GROUP BY t_dat, customer_id, article_id, price, sales_channel_id
)
SELECT SUM(row_count) AS total_rows,
       COUNT(*) AS distinct_record_combinations,
       SUM(row_count - 1) AS excess_identical_rows,
       ROUND(100.0 * SUM(row_count - 1) / NULLIF(SUM(row_count), 0), 2)
           AS identical_row_pct
FROM grouped;

-- 6. Coverage of observed customer purchasing history
WITH customer_history AS (
    SELECT customer_id,
           MIN(TRY_CAST(t_dat AS DATE)) AS first_purchase,
           MAX(TRY_CAST(t_dat AS DATE)) AS last_purchase,
           COUNT(DISTINCT t_dat) AS purchase_days
    FROM read_csv('transactions_train.csv', all_varchar = true)
    GROUP BY customer_id
)
SELECT COUNT(*) AS purchasing_customers,
       COUNT(*) FILTER (WHERE purchase_days = 1) AS single_day_customers,
       COUNT(*) FILTER (WHERE purchase_days > 1) AS multi_day_customers,
       COUNT(*) FILTER (WHERE DATE_DIFF('day', first_purchase, last_purchase) >= 30) AS history_30plus_days,
       COUNT(*) FILTER (WHERE DATE_DIFF('day', first_purchase, last_purchase) >= 90) AS history_90plus_days,
       COUNT(*) FILTER (WHERE DATE_DIFF('day', first_purchase, last_purchase) >= 180) AS history_180plus_days,
       COUNT(*) FILTER (WHERE DATE_DIFF('day', first_purchase, last_purchase) >= 365) AS history_365plus_days
FROM customer_history;

-- 7. Time coverage and channel-code distribution
SELECT DATE_TRUNC('month', TRY_CAST(t_dat AS DATE)) AS transaction_month,
       COUNT(*) AS recorded_transaction_rows,
       COUNT(DISTINCT customer_id) AS purchasing_customers
FROM read_csv('transactions_train.csv', all_varchar = true)
GROUP BY 1 ORDER BY 1;

-- Channel 1 and 2 meanings are not verified; retain neutral labels.
SELECT sales_channel_id,
       COUNT(*) AS recorded_transaction_rows,
       COUNT(DISTINCT customer_id) AS purchasing_customers
FROM read_csv('transactions_train.csv', all_varchar = true)
GROUP BY sales_channel_id ORDER BY sales_channel_id;
