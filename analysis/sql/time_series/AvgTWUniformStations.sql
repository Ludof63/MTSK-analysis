--same as AvgTimeWeighted.sql but do not make difference between stations

EXPLAIN
WITH param AS (
    SELECT
    '2023-01-20T23:00:00Z'::TIMESTAMP AS start_t,
    '2024-01-31T22:59:59Z'::TIMESTAMP AS end_t,
    '1 hour'::INTERVAL AS time_granularity,
    EXTRACT(EPOCH FROM time_granularity) AS interval_seconds,
    EXTRACT(EPOCH FROM (end_t - start_t)) AS number_seconds
),
time_series AS (
    SELECT  
        start_t + ((i * interval_seconds) * INTERVAL '1 second') AS bucket_start, 
        bucket_start + (interval_seconds * INTERVAL '1 second') as bucket_end,
        EXTRACT(dow FROM bucket_start) AS day_of_week, -- for day_bit
        (CASE WHEN day_of_week = 0 THEN 6 ELSE day_of_week -1 END ) as day_bit --for flextime stations
    FROM param, generate_series(0, (param.number_seconds / param.interval_seconds)) AS i
),
stations_info AS(
    SELECT s.id as station_id, city, brand, always_open FROM stations s, param
    WHERE EXISTS (SELECT station_uuid from prices p where p.station_uuid = s.id AND p.time BETWEEN param.start_t AND param.end_t)-- avoid inactive stations
    --and always_open -- and city = 'Berlin'
),
stations_prices AS (
   SELECT time as valid_from, diesel as price, s.*
    FROM param, prices p, stations_info s
    WHERE s.station_id = p.station_uuid
    AND diesel_change IN (1,3) AND time BETWEEN param.start_t AND param.end_t

    UNION ALL

    SELECT  param.start_t AS valid_from, price, s.*     --add last event before start
    FROM param, stations_info s, (
        SELECT time as valid_from, diesel as price
        FROM prices pp, param
        WHERE s.station_id = pp.station_uuid AND diesel_change IN (1,3)
        AND time <= param.start_t AND time >= param.start_t - '2 day'::INTERVAL 
        ORDER BY time DESC LIMIT 1
    ) p
),
prices_intervals AS (
    SELECT LEAD(valid_from, 1, param.end_t) OVER (PARTITION BY station_id ORDER BY valid_from) AS valid_until, sp.*
    FROM stations_prices sp, param
),
prices_time_series AS (
    SELECT bucket_start, EXTRACT(EPOCH FROM (LEAST(bucket_start, valid_until) - GREATEST(bucket_end, valid_from))) as duration_seconds, p_int.*
    FROM  time_series ts, prices_intervals p_int,
    WHERE (valid_from,valid_until) OVERLAPS (bucket_start, bucket_end)
)
select bucket_start as datetime, SUM(price * duration_seconds) / SUM(duration_seconds) as avg_diesel_price,
from prices_time_series
group by datetime
order by datetime;










-- COUNT(DISTINCT ts.station_id) active_stations -- ts.station_id, price, GREATEST(from_t, valid_from) as from_t, LEAST(to_t, valid_until)  as to_t,
-- group by bucket_start
-- order by bucket_start;
