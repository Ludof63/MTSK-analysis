WITH param AS (
    SELECT
    '2024-01-08T00:00:00Z'::TIMESTAMP AS start_t,
    '2024-01-21T23:59:59Z'::TIMESTAMP AS end_t,
    '1 day'::INTERVAL AS time_granularity,
     EXTRACT(EPOCH FROM time_granularity) AS interval_seconds,
),
time_series AS (
    SELECT  start_t + (((i-1) * interval_seconds) * INTERVAL '1 second') AS bucket_start, 
            bucket_start + (interval_seconds * INTERVAL '1 second') as bucket_end,
    FROM param, generate_series(1 , (EXTRACT(EPOCH FROM (end_t - start_t)) / interval_seconds)) AS i
),
updates AS (
    SELECT bucket_start, station_uuid
    FROM prices, time_series
    WHERE (diesel_change IN (1,3) OR e5_change IN (1,3) OR e10_change IN (1,3))
        AND time BETWEEN bucket_start AND bucket_end
)
SELECT bucket_start as datetime, count(*) as n_updates
FROM updates
GROUP BY datetime ORDER BY datetime;
