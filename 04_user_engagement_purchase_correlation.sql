WITH event_data AS (
    SELECT
        DATE(TIMESTAMP_MICROS(event_timestamp)) AS event_date,
        user_pseudo_id,
        (
            SELECT value.int_value
            FROM UNNEST(event_params)
            WHERE key = 'ga_session_id'
        ) AS session_id,
        event_name,

        COALESCE(
            (
                SELECT value.int_value
                FROM UNNEST(event_params)
                WHERE key = 'session_engaged'
            ),
            0
        ) AS session_engaged,

        COALESCE(
            (
                SELECT value.int_value
                FROM UNNEST(event_params)
                WHERE key = 'engagement_time_msec'
            ),
            0
        ) AS engagement_time_msec

    FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
    WHERE _TABLE_SUFFIX BETWEEN '20210101' AND '20211231'
),

session_data AS (
    SELECT
        user_pseudo_id,
        session_id,
        MAX(session_engaged) AS session_engaged,
        SUM(engagement_time_msec) AS engagement_time_msec,
        CASE
            WHEN COUNTIF(event_name = 'purchase') > 0 THEN 1
            ELSE 0
        END AS purchase
    FROM event_data
    GROUP BY user_pseudo_id, session_id
)

SELECT
    CORR(session_engaged, purchase) AS engagement_purchase_corr,
    CORR(engagement_time_msec, purchase) AS time_purchase_corr
FROM session_data;
