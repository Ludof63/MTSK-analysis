-- TIME-SERIES FROM START_T TO END_T
WITH param AS (
    SELECT
    '2024-01-08T00:00:00Z'::TIMESTAMP AS start_t,
    '2024-01-21T23:59:59Z'::TIMESTAMP AS end_t,
    '1 hour'::INTERVAL AS time_granularity,
     EXTRACT(EPOCH FROM time_granularity) AS interval_seconds,
),
time_series AS (
    SELECT  start_t + (((i-1) * interval_seconds) * INTERVAL '1 second') AS bucket_start, 
            bucket_start + (interval_seconds * INTERVAL '1 second') as bucket_end,
            (CASE WHEN EXTRACT(dow FROM bucket_start) = 0 THEN 6 ELSE EXTRACT(dow FROM bucket_start) -1 END ) as day_bit,
    FROM param, generate_series(1 , (EXTRACT(EPOCH FROM (end_t - start_t)) / interval_seconds)) AS i
)
select * from time_series order by bucket_start;


-- FOR TIME-SERIES FROM (END_T - RANGE_T) TO START
WITH param AS (
    SELECT 
    '2024-01-21T23:59:59Z'::TIMESTAMP AS end_t,
    '1 hour'::INTERVAL AS time_granularity,
    '10 hour'::INTERVAL AS range_t,
    end_t - range_t as start_t,
    EXTRACT(EPOCH FROM time_granularity) AS interval_seconds,
)