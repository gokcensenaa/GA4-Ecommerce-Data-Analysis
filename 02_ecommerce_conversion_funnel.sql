WITH events_data AS (
    SELECT
        DATE(TIMESTAMP_MICROS(event_timestamp)) AS event_date,
        user_pseudo_id,
        (
            SELECT value.int_value
            FROM UNNEST(event_params)
            WHERE key = 'ga_session_id'
        ) AS session_id,
        event_name,
        traffic_source.source AS source,
        traffic_source.medium AS medium,
        traffic_source.name AS campaign
    FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
    WHERE _TABLE_SUFFIX BETWEEN '20210101' AND '20211231'
      AND event_name IN (
          'session_start',
          'add_to_cart',
          'begin_checkout',
          'purchase'
      )
),

session AS (
    SELECT
        user_pseudo_id,
        session_id,
        event_date,
        source,
        medium,
        campaign,
        COUNTIF(event_name = 'session_start') AS session_start_count,
        COUNTIF(event_name = 'add_to_cart') AS add_to_cart_count,
        COUNTIF(event_name = 'begin_checkout') AS begin_checkout_count,
        COUNTIF(event_name = 'purchase') AS purchase_count
    FROM events_data
    GROUP BY
        user_pseudo_id,
        session_id,
        event_date,
        source,
        medium,
        campaign
)

SELECT
    event_date,
    source,
    medium,
    campaign,
    COUNT(DISTINCT CONCAT(user_pseudo_id, CAST(session_id AS STRING))) AS user_sessions_count,
    COUNT(DISTINCT IF(add_to_cart_count > 0, CONCAT(user_pseudo_id, CAST(session_id AS STRING)), NULL)) AS visit_to_cart,
    COUNT(DISTINCT IF(begin_checkout_count > 0, CONCAT(user_pseudo_id, CAST(session_id AS STRING)), NULL)) AS visit_to_checkout,
    COUNT(DISTINCT IF(purchase_count > 0, CONCAT(user_pseudo_id, CAST(session_id AS STRING)), NULL)) AS visit_to_purchase
FROM session
WHERE session_start_count > 0
GROUP BY event_date, source, medium, campaign;
