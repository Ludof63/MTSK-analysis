WITH param AS (
    SELECT '2024-01-31 17:00'::TIMESTAMP AS time_t, 
        (CASE WHEN EXTRACT(dow FROM time_t) = 0 THEN 6 ELSE EXTRACT(dow FROM time_t) -1 END ) as day_bit,
),

WITH param AS (
    SELECT (select max(time) from prices) AS time_t, 
    (CASE WHEN EXTRACT(dow FROM time_t) = 0 THEN 6 ELSE EXTRACT(dow FROM time_t) -1 END ) as day_bit,
),

$latitude as lat, $longitude as lon, $dst_threshold AS dst_threshold

-----------------------------------------
WITH param AS (
    SELECT
    '2024-01-08T00:00:00Z'::TIMESTAMP AS start_t,
    '2024-01-21T23:59:59Z'::TIMESTAMP AS end_t,
    '1 hour'::INTERVAL AS time_granularity,
     EXTRACT(EPOCH FROM time_granularity) AS interval_seconds,
),

WITH param AS (
    SELECT (select max(time) from prices) as end_t,
    '10 hours'::INTERVAL AS range_t,
    end_t - range_t as start_t,
    '1 hour'::INTERVAL AS time_granularity,
     EXTRACT(EPOCH FROM time_granularity) AS interval_seconds,
),

WITH param AS (
    SELECT (select max(time) from prices) as end_t,
     ( $__timeTo()::TIMESTAMP - $__timeFrom()::TIMESTAMP) as range_t,
    end_t - range_t as start_t, 
    '${time_granularity}'::INTERVAL AS time_granularity,
     EXTRACT(EPOCH FROM time_granularity) AS interval_seconds,
),