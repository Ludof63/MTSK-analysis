WITH param AS (
    SELECT 
    (select max(time) from prices) as end_t,
    '10 seconds'::INTERVAL AS time_granularity,
    '10 hours'::INTERVAL AS range_t,
    end_t - range_t as start_t,
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
select bucket_start as datetime, count(*)
from updates
group by datetime;