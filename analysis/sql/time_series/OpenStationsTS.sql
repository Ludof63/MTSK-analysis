WITH param AS (
    SELECT
    '2024-10-07T00:00:00Z'::TIMESTAMP AS start_t,
    '2024-10-13T23:59:59Z'::TIMESTAMP AS end_t,
    '1 day'::INTERVAL AS time_granularity,
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
flextime_buckets AS(
    SELECT
        bucket_start, station_id, bucket_start::date + open_time as from , bucket_end::date + close_time as to
    FROM param, time_series, stations_times, stations s
    WHERE station_id = id AND first_active <= bucket_start
        AND (days & (1 << (day_bit))) > 0 -- open day?
        AND (bucket_start::date + open_time, bucket_start::date + close_time) OVERLAPS (bucket_start, bucket_end) -- opening hours?
        AND EXISTS (SELECT station_uuid from prices p where p.station_uuid = s.id AND p.time BETWEEN param.start_t AND param.end_t)-- avoid inactive stations
),
alwaysopen_buckets AS (
    SELECT bucket_start, id as station_id, bucket_start as from , bucket_end as to
    FROM param, time_series, stations s WHERE always_open AND first_active <= bucket_start
    AND EXISTS (SELECT station_uuid from prices p where p.station_uuid = s.id AND p.time BETWEEN param.start_t AND param.end_t)-- avoid inactive stations
),
stations_time_series AS (
    SELECT * FROM  flextime_buckets UNION ALL SELECT * FROM alwaysopen_buckets
)
select bucket_start as datetime, COUNT(station_id) as n_open_stations from stations_time_series
group by bucket_start
order by  bucket_start;