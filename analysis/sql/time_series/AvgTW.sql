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
),
active_stations AS(
    SELECT s.id as station_id, city, brand, always_open, first_active 
    FROM stations s, param
    WHERE EXISTS (SELECT station_uuid from prices p where p.station_uuid = s.id AND p.time BETWEEN end_t - INTERVAL '3 day' AND end_t)-- avoid inactive stations
),
flextime_buckets AS(
    SELECT bucket_start, s.station_id, bucket_start::date + open_time as from_t , bucket_end::date + close_time as to_t
    FROM time_series, stations_times st, active_stations s
    WHERE st.station_id = s.station_id  AND first_active <= bucket_start
        AND (days & (1 << (day_bit))) > 0 -- open day?
        AND (bucket_start::date + open_time, bucket_start::date + close_time) OVERLAPS (bucket_start, bucket_end) -- opening hours?
),
alwaysopen_buckets AS (
    SELECT bucket_start, station_id, bucket_start as from_t , bucket_end as to_t
    FROM time_series, active_stations 
    WHERE always_open AND first_active <= bucket_start
),
stations_time_series AS (
    SELECT * FROM  flextime_buckets UNION ALL SELECT * FROM alwaysopen_buckets
),
stations_prices AS (
   SELECT time as valid_from, diesel as price, s.*
    FROM param, prices p, active_stations s
    WHERE s.station_id = p.station_uuid
    AND diesel_change IN (1,3) AND time BETWEEN param.start_t AND param.end_t

    UNION ALL

    SELECT  param.start_t AS valid_from, price, s.* --add last event before start
    FROM param, active_stations s, (
        SELECT time as valid_from, diesel as price
        FROM prices pp, param
        WHERE s.station_id = pp.station_uuid AND diesel_change IN (1,3)
        AND time <= start_t AND time >= start_t - '3 day'::INTERVAL 
        ORDER BY time DESC LIMIT 1
    ) p
), 
prices_intervals AS (
    SELECT LEAD(valid_from, 1, param.end_t) OVER (PARTITION BY station_id ORDER BY valid_from) AS valid_until, sp.*
    FROM stations_prices sp, param
),
prices_time_series AS (
    SELECT bucket_start, EXTRACT(EPOCH FROM (LEAST(to_t, valid_until) - GREATEST(from_t, valid_from))) as duration_seconds, p_int.*
    FROM  stations_time_series ts, prices_intervals p_int,
    WHERE ts.station_id = p_int.station_id AND (valid_from,valid_until) OVERLAPS (from_t, to_t)
)
SELECT bucket_start as datetime, SUM(price * duration_seconds) / SUM(duration_seconds) as avg_diesel_price,
FROM prices_time_series
GROUP BY datetime ORDER BY datetime;