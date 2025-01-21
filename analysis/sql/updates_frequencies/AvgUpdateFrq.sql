WITH param AS (
    SELECT  
        '2024-10-01'::TIMESTAMP AS start,
        '2024-11-30'::TIMESTAMP AS end,
), 
WITH price_differences AS (
    SELECT
        station_uuid, time,
        LAG(time) OVER (PARTITION BY station_uuid ORDER BY time) AS previous_time
    FROM prices, param
    WHERE (diesel_change IN (1,3) OR e5_change IN (1,3) OR e10_change IN (1,3)) --any price update
    AND time BETWEEN param.start and param.end
),
time_differences AS (
    SELECT station_uuid, EXTRACT(EPOCH FROM (time - previous_time)) AS sec_between_updates
    FROM price_differences
    WHERE previous_time IS NOT NULL
),
station_frq AS (
    SELECT station_uuid, AVG(sec_between_updates)/60 AS avg_min_between_updates
    FROM time_differences
    GROUP BY station_uuid
),
percentiles AS (
    SELECT
        percentile_cont(0.50) WITHIN GROUP (ORDER BY avg_min_between_updates) AS p50,
        percentile_cont(0.75) WITHIN GROUP (ORDER BY avg_min_between_updates) AS p75,
        percentile_cont(0.90) WITHIN GROUP (ORDER BY avg_min_between_updates) AS p90,
        percentile_cont(0.95) WITHIN GROUP (ORDER BY avg_min_between_updates) AS p95
    FROM station_frq
)
SELECT p50, p75, p90, p95 FROM percentiles;
