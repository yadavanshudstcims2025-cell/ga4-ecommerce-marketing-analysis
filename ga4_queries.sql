-- ============================================================================
-- E-commerce Marketing Analysis: GA4 sample data (BigQuery Standard SQL)
-- Dataset: bigquery-public-data.ga4_obfuscated_sample_ecommerce (Google Merchandise Store)
-- Period : 2020-11-01 to 2021-01-31
-- Run each query in the BigQuery console (free sandbox) and export the result
-- to Google Sheets / CSV using the file name given above the query.
-- Note: traffic_source in this sample is the USER's first-visit source, not the
--       source of each session.
-- ============================================================================


-- ----------------------------------------------------------------------------
-- Query 1 -> daily_overview.csv
-- Daily sessions, users, purchase sessions, orders and revenue
-- ----------------------------------------------------------------------------
WITH base AS (
  SELECT
    PARSE_DATE('%Y%m%d', event_date) AS event_date,
    user_pseudo_id,
    CONCAT(user_pseudo_id, '-',
           CAST((SELECT value.int_value FROM UNNEST(event_params)
                 WHERE key = 'ga_session_id') AS STRING)) AS session_id,
    event_name,
    ecommerce.transaction_id AS transaction_id,
    ecommerce.purchase_revenue AS revenue
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
)
SELECT
  event_date,
  COUNT(DISTINCT session_id)                                        AS sessions,
  COUNT(DISTINCT user_pseudo_id)                                    AS users,
  COUNT(DISTINCT IF(event_name = 'purchase', session_id, NULL))     AS purchase_sessions,
  COUNT(DISTINCT IF(event_name = 'purchase', transaction_id, NULL)) AS orders,
  SUM(IF(event_name = 'purchase', IFNULL(revenue, 0), 0))           AS revenue
FROM base
GROUP BY event_date
ORDER BY event_date;


-- ----------------------------------------------------------------------------
-- Query 2 -> channel_performance.csv
-- Performance by first-visit source / medium
-- ----------------------------------------------------------------------------
WITH base AS (
  SELECT
    user_pseudo_id,
    CONCAT(user_pseudo_id, '-',
           CAST((SELECT value.int_value FROM UNNEST(event_params)
                 WHERE key = 'ga_session_id') AS STRING)) AS session_id,
    event_name,
    traffic_source.source AS source,
    traffic_source.medium AS medium,
    ecommerce.purchase_revenue AS revenue
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
)
SELECT
  source,
  medium,
  COUNT(DISTINCT session_id)                                    AS sessions,
  COUNT(DISTINCT user_pseudo_id)                                AS users,
  COUNT(DISTINCT IF(event_name = 'purchase', session_id, NULL)) AS purchase_sessions,
  SUM(IF(event_name = 'purchase', IFNULL(revenue, 0), 0))       AS revenue
FROM base
GROUP BY source, medium
HAVING sessions >= 100            -- drop tiny sources so rates are meaningful
ORDER BY revenue DESC;


-- ----------------------------------------------------------------------------
-- Query 3 -> funnel.csv
-- Sessions reaching each step of the purchase funnel
-- ----------------------------------------------------------------------------
WITH s AS (
  SELECT
    CONCAT(user_pseudo_id, '-',
           CAST((SELECT value.int_value FROM UNNEST(event_params)
                 WHERE key = 'ga_session_id') AS STRING)) AS session_id,
    event_name
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
    AND event_name IN ('session_start', 'view_item', 'add_to_cart',
                       'begin_checkout', 'purchase')
),
agg AS (
  SELECT
    COUNT(DISTINCT IF(event_name = 'session_start',  session_id, NULL)) AS s1,
    COUNT(DISTINCT IF(event_name = 'view_item',      session_id, NULL)) AS s2,
    COUNT(DISTINCT IF(event_name = 'add_to_cart',    session_id, NULL)) AS s3,
    COUNT(DISTINCT IF(event_name = 'begin_checkout', session_id, NULL)) AS s4,
    COUNT(DISTINCT IF(event_name = 'purchase',       session_id, NULL)) AS s5
  FROM s
)
SELECT 1 AS step_order, 'Session start'  AS step, s1 AS sessions FROM agg UNION ALL
SELECT 2, 'View item',      s2 FROM agg UNION ALL
SELECT 3, 'Add to cart',    s3 FROM agg UNION ALL
SELECT 4, 'Begin checkout', s4 FROM agg UNION ALL
SELECT 5, 'Purchase',       s5 FROM agg
ORDER BY step_order;


-- ----------------------------------------------------------------------------
-- Query 4 -> user_segments.csv
-- New vs returning visitors by device category
-- ----------------------------------------------------------------------------
WITH base AS (
  SELECT
    CONCAT(user_pseudo_id, '-',
           CAST((SELECT value.int_value FROM UNNEST(event_params)
                 WHERE key = 'ga_session_id') AS STRING)) AS session_id,
    (SELECT value.int_value FROM UNNEST(event_params)
      WHERE key = 'ga_session_number') AS session_number,
    device.category AS device_category,
    event_name,
    ecommerce.purchase_revenue AS revenue
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201101' AND '20210131'
)
SELECT
  IF(session_number = 1, 'New', 'Returning')                    AS user_type,
  device_category,
  COUNT(DISTINCT session_id)                                    AS sessions,
  COUNT(DISTINCT IF(event_name = 'purchase', session_id, NULL)) AS purchase_sessions,
  SUM(IF(event_name = 'purchase', IFNULL(revenue, 0), 0))       AS revenue
FROM base
WHERE session_number IS NOT NULL
GROUP BY user_type, device_category
ORDER BY sessions DESC;
