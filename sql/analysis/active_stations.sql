--NUMBER OF ACTIVE STATIONS AS A TIME-SERIES----------------------------------------------------------------
WITH param AS (
    SELECT  '1 hour'::INTERVAL AS time_granularity,
            '2024-11-01'::TIMESTAMP AS start,
            '2024-11-11'::TIMESTAMP AS end,
           EXTRACT(EPOCH FROM time_granularity)::INTEGER AS interval_seconds
),
time_series AS (
    SELECT  param.start + ((i * interval_seconds) *INTERVAL '1 second') AS time_bucket_start,
            param.start + (((i + 1) * param.interval_seconds) * INTERVAL '1 second') AS time_bucket_end,
            EXTRACT(dow FROM time_bucket_start) AS day_of_week,
            (CASE WHEN day_of_week = 0 THEN 6 ELSE day_of_week -1 END ) as day_bit

    FROM param, generate_series(0, ((EXTRACT(EPOCH FROM param.end) - EXTRACT(EPOCH FROM param.start)) / param.interval_seconds)::INTEGER) AS i
),
always_open_count AS(
    SELECT COUNT(s.id) as n_always_open,
    FROM stations s, param
    WHERE s.always_open
    AND EXISTS (SELECT station_uuid from prices p where p.station_uuid = s.id AND p.time >= param.start AND p.time <= param.end ) -- at least one event
),
flextime_open AS(
    SELECT
        time_bucket_start, station_id, -- open_time, close_time
        
    FROM stations_times st, time_series t, param
    WHERE (st.days & (1 << (t.day_bit))) > 0 -- time bucket is in an open day
    AND (time_bucket_start, time_bucket_end) OVERLAPS (time_bucket_start::date + open_time, time_bucket_start::date + close_time) --time bucket is in opening times
    AND EXISTS (SELECT station_uuid from prices p where p.station_uuid = st.station_id AND p.time >= param.start AND p.time <= param.end ) -- at least one event
)
SELECT time_bucket_start as time, COUNT(station_id) as n_flextime, n_always_open, n_flextime +n_always_open as n_open_stations
FROM flextime_open, always_open_count
GROUP BY time_bucket_start
ORDER BY time_bucket_start;