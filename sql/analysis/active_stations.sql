-- ACTIVE STATIONS
WITH param AS (
    SELECT  '1 hour'::INTERVAL AS time_granularity,
            '2024-11-4'::TIMESTAMP as start,
            '2024-11-11'::TIMESTAMP as end,
           EXTRACT(EPOCH FROM time_granularity)::INTEGER AS interval_seconds
),
time_series AS (
    SELECT 
        param.start + ((i * interval_seconds) *INTERVAL '1 second') AS time_bucket_start,
        param.start + (((i + 1) * param.interval_seconds) * INTERVAL '1 second') AS time_bucket_end,
        EXTRACT(dow FROM time_bucket_start) AS day_of_week,
        (CASE
            WHEN day_of_week = 0 THEN 6
            ELSE day_of_week -1
        END ) as day_bit

    FROM param, generate_series(0, (EXTRACT(EPOCH FROM (param.end - param.start)) / param.interval_seconds)::INTEGER) AS i
),
open_stations AS(
    SELECT 
        time_bucket_start, station_id
    FROM time_series t, stations_times s
    WHERE (s.days & (1 << (t.day_bit))) > 0  -- is open that day_of_week
    AND open_time <= time_bucket_start::time AND close_time >= time_bucket_end::time -- open for the entire time bucket
),
always_open AS(
    SELECT COUNT(id) as n_always_open FROM stations WHERE always_open --add the stations that are always open
)
SELECT time_bucket_start as time, COUNT(station_id) + n_always_open as n_stations
FROM open_stations, always_open
GROUP BY time_bucket_start
ORDER BY time_bucket_start;
