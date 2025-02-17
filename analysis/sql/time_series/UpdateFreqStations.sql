WITH param AS (
    SELECT
    '2024-01-01T00:00:00Z'::TIMESTAMP AS start_t,
    '2024-01-31T23:59:59Z'::TIMESTAMP AS end_t,
), 
WITH price_differences AS (
    SELECT station_uuid, time, LAG(time) OVER (PARTITION BY station_uuid ORDER BY time) AS previous_time
    FROM prices, param
    WHERE (diesel_change IN (1,3) OR e5_change IN (1,3) OR e10_change IN (1,3))
    AND time BETWEEN start_t and end_t
),
time_differences AS (
    SELECT station_uuid, EXTRACT(EPOCH FROM (time - previous_time)) AS s_between_updates
    FROM price_differences
    WHERE previous_time IS NOT NULL --ignore first event in range
),
station_frq AS (
    SELECT station_uuid, AVG(s_between_updates)/60 AS avg_min_between_updates
    FROM time_differences
    GROUP BY station_uuid
),
stats AS (
  SELECT COUNT(*) AS total_stations,
    COUNT(CASE WHEN avg_min_between_updates <= (3*24*60) THEN 1 END) AS under_three_days 
  FROM station_frq
)
SELECT under_three_days::numeric/total_stations * 100 as percentage
FROM stats;