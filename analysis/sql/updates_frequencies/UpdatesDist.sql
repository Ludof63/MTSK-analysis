EXPLAIN
WITH param AS (
    SELECT  
        '7 hours'::INTERVAL AS time_granularity,
        '2024-10-01'::TIMESTAMP AS start,
        '2024-10-15'::TIMESTAMP AS end,
        EXTRACT(EPOCH FROM time_granularity)::INTEGER AS interval_seconds
),
time_series AS (
    SELECT  param.start + ((i * interval_seconds) *INTERVAL '1 second') AS time_bucket_start,
            param.start + (((i + 1) * param.interval_seconds) * INTERVAL '1 second') AS time_bucket_end,
    FROM param, generate_series(0, ((EXTRACT(EPOCH FROM param.end) - EXTRACT(EPOCH FROM param.start)) / param.interval_seconds)::INTEGER) AS i
)
SELECT time_bucket_start as time_bucket, COUNT(*) as n_updates
FROM prices, time_series
WHERE   time BETWEEN time_bucket_start and time_bucket_end
        AND (diesel_change IN (1,3) OR e5_change IN (1,3) OR e10_change IN (1,3)) --any price update
GROUP BY time_bucket
ORDER BY time_bucket;


WITH param AS (
    SELECT  
        '2024-10-01'::TIMESTAMP AS start,
        '2024-10-15'::TIMESTAMP AS end,
        'hour' AS granularity,
        EXTRACT(EPOCH FROM ('1' || granularity)::INTERVAL)::INTEGER AS interval_seconds
),
time_series AS (
    SELECT  param.start + ((i * interval_seconds) *INTERVAL '1 second') AS time_bucket,
    FROM param, generate_series(0, ((EXTRACT(EPOCH FROM param.end) - EXTRACT(EPOCH FROM param.start)) / param.interval_seconds)::INTEGER) AS i
),
entries_per_granularity AS (
    SELECT date_trunc(param.granularity, time) AS datetime, COUNT(*) as n_entries
    FROM prices, param
    WHERE (diesel_change IN (1,3) OR e5_change IN (1,3) OR e10_change IN (1,3))
    GROUP BY datetime
),
all_bucket
select * from entries_per_granularity order by datetime;



WITH entries_per_second AS (
    SELECT date_trunc('second', time) AS datetime, COUNT(*) as n_entries
    FROM prices
    WHERE (diesel_change IN (1,3) OR e5_change IN (1,3) OR e10_change IN (1,3))
    GROUP BY datetime
)


