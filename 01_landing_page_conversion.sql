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
        event_timestamp,
        (
            SELECT value.string_value
            FROM UNNEST(event_params)
            WHERE key = 'page_location'
        ) AS page_location
    FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
    WHERE EXTRACT(YEAR FROM TIMESTAMP_MICROS(event_timestamp)) = 2020
),

page_path AS (
    SELECT *,
        REGEXP_EXTRACT(
            page_location,
            r'https?://[^/]+(/[^?]*)'
        ) AS page_path
    FROM events_data
),

landing_page AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY user_pseudo_id, session_id
            ORDER BY event_timestamp
        ) AS row_num
    FROM page_path
    WHERE event_name = 'page_view'
),

purchase AS (
    SELECT
        user_pseudo_id,
        session_id,
        MAX(IF(event_name = 'purchase', 1, 0)) AS has_purchase
    FROM page_path
    GROUP BY user_pseudo_id, session_id
)

SELECT
    landing_page.page_path,
    COUNT(DISTINCT CONCAT(
        landing_page.user_pseudo_id,
        CAST(landing_page.session_id AS STRING)
    )) AS user_sessions_count,
    SUM(purchase.has_purchase) AS purchase_count,
    ROUND(
        SUM(purchase.has_purchase) * 100.0 /
        COUNT(DISTINCT CONCAT(
            landing_page.user_pseudo_id,
            CAST(landing_page.session_id AS STRING)
        )),
        2
    ) AS purchase_conversion_rate
FROM landing_page
LEFT JOIN purchase
    ON landing_page.user_pseudo_id = purchase.user_pseudo_id
    AND landing_page.session_id = purchase.session_id
WHERE row_num = 1
GROUP BY landing_page.page_path;
