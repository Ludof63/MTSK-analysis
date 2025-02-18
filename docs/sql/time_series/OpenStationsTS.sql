WITH param AS (
    SELECT
    '2024-01-08T00:00:00Z'::TIMESTAMP AS start_t,
    '2024-01-14T23:59:59Z'::TIMESTAMP AS end_t,
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
)
SELECT bucket_start as datetime, COUNT(distinct station_id) as n_open_stations 
FROM stations_time_series
GROUP BY bucket_start ORDER BY bucket_start;