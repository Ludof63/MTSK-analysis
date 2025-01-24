WITH param AS (
    SELECT
    '2024-10-07T00:00:00Z'::TIMESTAMP AS start_t,
    '2024-10-13T23:59:59Z'::TIMESTAMP AS end_t,
    '1 hour'::INTERVAL AS time_granularity,
    EXTRACT(EPOCH FROM time_granularity) AS interval_seconds,
    EXTRACT(EPOCH FROM (end_t - start_t)) AS number_seconds
),
time_series AS (
    SELECT  start_t + ((i * interval_seconds) * INTERVAL '1 second') AS bucket_start, 
            bucket_start + (interval_seconds * INTERVAL '1 second') as bucket_end,
            EXTRACT(dow FROM bucket_start) AS day_of_week, -- needed only for day_bit
            (CASE WHEN day_of_week = 0 THEN 6 ELSE day_of_week -1 END ) as day_bit --needed for flextime stations
    FROM param, generate_series(0, (param.number_seconds / param.interval_seconds)) AS i
)
select * from time_series order by bucket_start;


-- for grafana
WITH param AS (
    SELECT
    $__timeFrom()::TIMESTAMP AS start_t,
    $__timeTo()::TIMESTAMP AS end_t,
    '1 $time_granularity'::INTERVAL AS time_granularity,
    EXTRACT(EPOCH FROM time_granularity) AS interval_seconds,
    EXTRACT(EPOCH FROM (end_t - start_t)) AS number_seconds
)
