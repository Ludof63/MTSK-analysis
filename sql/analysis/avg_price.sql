-- ALL STATIONS, DATE-TRUNC (each price update counted uniformly)
WITH param AS (
    SELECT 'hour' AS time_granularity,
    '2024-11-01'::TIMESTAMP AS start,
    '2024-11-11'::TIMESTAMP AS end,
)
SELECT 
    date_trunc(time_granularity, p.time) AS datetime,
    --COUNT(DISTINCT s.id) n_stations,
    AVG(p.diesel) as avg_diesel_price
FROM 
	stations s JOIN prices p ON s.id = p.station_uuid 
    JOIN param ON true
WHERE
	p.diesel_change IN (1, 3) 
    AND p.time >= param.start AND p.time <= param.end
GROUP BY
    date_trunc(time_granularity, p.time)
ORDER BY 
    datetime;






-- ALWAYS OPEN STATIONS TIME-WEIGHTED-----------------------------------------------------------------
SET implicit_cross_products = OFF; 

EXPLAIN
WITH param AS (
    SELECT  '1 hour'::INTERVAL AS time_granularity,
            '2024-11-01'::TIMESTAMP AS start,
            '2024-11-8'::TIMESTAMP AS end,
           EXTRACT(EPOCH FROM time_granularity)::INTEGER AS interval_seconds
),
time_series AS (
    SELECT  param.start + ((i * interval_seconds) *INTERVAL '1 second') AS time_bucket_start,
            param.start + (((i + 1) * param.interval_seconds) * INTERVAL '1 second') AS time_bucket_end,
            DATE_TRUNC('day', time_bucket_start) AS bucket_day,
            EXTRACT(dow FROM time_bucket_start) AS day_of_week,
            (CASE WHEN day_of_week = 0 THEN 6 ELSE day_of_week -1 END ) as day_bit

    FROM param, generate_series(0, ((EXTRACT(EPOCH FROM param.end) - EXTRACT(EPOCH FROM param.start)) / param.interval_seconds)::INTEGER) AS i
),
first_bucket AS (
    SELECT time_bucket_start, time_bucket_end FROM time_series,param WHERE time_bucket_start = start
),
alwaysopen_stations AS(
    SELECT
        s.id AS station_id, city, always_open,
    FROM stations s, param
    WHERE s.always_open AND s.city in ('Berlin') 
    AND EXISTS (SELECT station_uuid from prices where station_uuid = id AND time >= param.start AND time <= param.end ) 
),
first_bucket_stations AS(
    SELECT
        s.station_id, city, always_open,
        f.time_bucket_start, f.time_bucket_end,
    FROM alwaysopen_stations s, first_bucket f
),
last_even_before_start AS(
    SELECT
        station_id, city, always_open,
        time_bucket_start, time_bucket_end,
        p.diesel AS price,
        p.time AS real_time,
    FROM first_bucket_stations s
    asof JOIN prices p ON p.time <= s.time_bucket_start AND p.station_uuid = s.station_id
    WHERE diesel_change IN (1, 3) 
)
SELECT * from last_even_before_start order by station_id, real_time;



EXPLAIN
WITH param AS (
    SELECT  '1 hour'::INTERVAL AS time_granularity,
            '2024-11-01'::TIMESTAMP AS start,
            '2024-11-8'::TIMESTAMP AS end,
           EXTRACT(EPOCH FROM time_granularity)::INTEGER AS interval_seconds
),
time_series AS (
    SELECT  param.start + ((i * interval_seconds) *INTERVAL '1 second') AS time_bucket_start,
            param.start + (((i + 1) * param.interval_seconds) * INTERVAL '1 second') AS time_bucket_end,
            DATE_TRUNC('day', time_bucket_start) AS bucket_day,
            EXTRACT(dow FROM time_bucket_start) AS day_of_week,
            (CASE WHEN day_of_week = 0 THEN 6 ELSE day_of_week -1 END ) as day_bit

    FROM param, generate_series(0, ((EXTRACT(EPOCH FROM param.end) - EXTRACT(EPOCH FROM param.start)) / param.interval_seconds)::INTEGER) AS i
),
first_bucket AS (
    SELECT time_bucket_start, time_bucket_end FROM time_series,param WHERE time_bucket_start = start
),
alwaysopen_stations AS(
    SELECT
        s.id AS station_id, city, always_open,
    FROM stations s, param
    WHERE s.always_open AND s.city in ('Berlin') 
    AND EXISTS (SELECT station_uuid from prices where station_uuid = id AND time >= param.start AND time <= param.end )
),
last_even_before_start AS(
    SELECT
        s.station_id, city, always_open,
        f.time_bucket_start, f.time_bucket_end,
        p.diesel AS price,
        p.time AS real_time,
    FROM alwaysopen_stations s, first_bucket f --label each station with first bucket
    asof JOIN (
        SELECT station_uuid,diesel,time
        FROM prices
        WHERE diesel_change IN (1, 3) 
    ) p ON p.station_uuid = s.station_id AND p.time <= f.time_bucket_start
)
SELECT * from last_even_before_start order by station_id, real_time;




always_open_active_buckets AS( --buckets with events in them
    SELECT
        station_id, city, always_open,
        time_bucket_start, time_bucket_end,
        p.diesel AS price,
        p.time as real_time
    FROM time_series t, alwaysopen_stations s
    JOIN (
        SELECT station_uuid, diesel, time
        FROM prices
        WHERE diesel_change IN (1, 3) AND time >= time_bucket_start AND time <= time_bucket_end
    ) p ON station_id = p.station_uuid  
)

event_before_start_alwaysopen AS( --last price before the first bucket for each station
    SELECT DISTINCT ON (s.station_id) --select only last
        s.station_id, city, always_open,
        f.time_bucket_start, f.time_bucket_end,
        p.diesel AS price,
        p.time AS real_time,
    FROM alwaysopen_stations s, first_bucket f, prices p
    WHERE s.station_id = p.station_uuid --look up to one day before in the station history to find events
    AND p.time <= f.time_bucket_start AND p.time >= f.time_bucket_start - '1 day'::INTERVAL 
    AND p.diesel_change IN (1, 3)
    ORDER BY s.station_id, p.time DESC
)

EXPLAIN
WITH fake_rel AS(
    SELECT 
        s.id, city, always_open,
        '2024-11-01'::TIMESTAMP as bucket
    FROM stations s WHERE s.id = '813ed58c-b58d-4d17-895b-2078cb302649'
),
expected_res AS(
    SELECT  id, city, always_open, bucket,
            p.diesel AS event_price,
            p.time AS event_time,
    FROM fake_rel s, (
        SELECT station_uuid, diesel, time
        FROM prices
        WHERE station_uuid = s.id AND diesel_change IN (1, 3)
        AND time <= s.bucket 
        AND time >= s.bucket - '1 day'::INTERVAL  -- to not run out of memory
        ORDER BY time DESC
        LIMIT 1
    ) p
)
SELECT 
    id, city, always_open, bucket,
    p.diesel AS event_price,
    p.time AS event_time,
FROM fake_rel s asof JOIN prices p ON p.time <= s.bucket AND s.id = p.station_uuid
WHERE p.diesel_change IN (1, 3);

SELECT * FROM expected_res
UNION ALL



UNION ALL



SELECT  id, city, always_open, bucket,
        p.diesel AS event_price,
        p.time AS event_time,
    FROM fake_rel s, (
        SELECT station_uuid,diesel,time
        FROM prices
        WHERE station_uuid = s.id AND time <= s.bucket
        AND diesel_change IN (1, 3);
        ORDER BY time DESC
        LIMIT 1
    ) p;


    WHERE s.station_id = p.station_uuid --look up to one day before in the station history to find events
    AND p.time <= f.time_bucket_start AND p.time >= f.time_bucket_start - '1 day'::INTERVAL 
    AND p.diesel_change IN (1, 3)
    ORDER BY s.station_id, p.time DESC




SELECT * FROM fake_rel;


SELECT 
    s.id, city, always_open,
    '2024-11-01'::TIMESTAMP as bucket
    p.diesel AS price,
    p.time AS real_time,
FROM stations s asof JOIN prices p ON p.time <= 
WHERE s.id = '813ed58c-b58d-4d17-895b-2078cb302649' AND p.diesel_change IN (1, 3);




always_open_active_buckets_complete AS(
    SELECT * from always_open_active_buckets
    UNION ALL
    SELECT * from event_before_start_alwaysopen
),
always_open_empty_buckets AS( -- buckets with no events (complementary )
    SELECT
        station_id, city, always_open,
        time_bucket_start, time_bucket_end,
        NULL AS price,
        NULL as real_time
    FROM time_series t CROSS JOIN alwaysopen_stations s  -- CROSS PRODUCT...not really??
    WHERE NOT EXISTS(SELECT * FROM always_open_active_buckets_complete b WHERE b.station_id = s.station_id AND b.time_bucket_start = t.time_bucket_start)
    AND       EXISTS(SELECT * FROM always_open_active_buckets_complete b WHERE b.station_id = s.station_id AND b.time_bucket_start <= t.time_bucket_start)
),
always_open_empty_buckets_fixed AS(
    SELECT
        station_id, city, always_open,
        time_bucket_start, time_bucket_end,
        p.price AS price,
        time_bucket_start as real_time --as if the price update was at the start of the bucket
    FROM always_open_empty_buckets e JOIN ( 
        SELECT price
        FROM always_open_active_buckets_complete b
        WHERE b.station_id = e.station_id --same station
        AND b.time_bucket_start <= e.time_bucket_start --previous bucket
        AND b.time_bucket_start >= e.time_bucket_start - '1 day'::INTERVAL --limit search space
        ORDER BY real_time DESC LIMIT 1 -- last
    ) p ON true
),
always_open_buckets AS(
    SELECT * from always_open_active_buckets_complete
    UNION ALL 
    SELECT * from always_open_empty_buckets_fixed
),
weighted_prices AS ( --compute duration of every price in its bucket
    SELECT 
        station_id,city,always_open,
        time_bucket_start,
        real_time,
        price,
        GREATEST(real_time, time_bucket_start) AS valid_from, 
        LEAD(real_time, 1, time_bucket_end) OVER (PARTITION BY station_id, time_bucket_start ORDER BY real_time) AS valid_until,
        EXTRACT(EPOCH FROM (valid_until - valid_from)) AS duration_seconds
    FROM always_open_buckets
)
SELECT 
    time_bucket_start AS time,
    --COUNT(DISTINCT station_id) AS n_station,
    SUM(price * duration_seconds) / SUM(duration_seconds) AS avg_diesel_price
FROM weighted_prices
GROUP BY time_bucket_start
ORDER BY time_bucket_start;











-- FLEXTIME STATIONS TIME-WEIGHTED-----------------------------------------------------------------
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
flextime_active AS(
    SELECT
        station_id, city, always_open,
        time_bucket_start, time_bucket_end,
        GREATEST(time_bucket_start, time_bucket_start::date + open_time) as start_time,
        LEAST(time_bucket_end, time_bucket_start::date + close_time) as end_time,
        
    FROM stations_times st, time_series t, stations s, param
    WHERE s.id = st.station_id AND city IN ('Berlin')
    AND (st.days & (1 << (t.day_bit))) > 0 -- time bucket is in an open day
    AND (time_bucket_start, time_bucket_end) OVERLAPS (time_bucket_start::date + open_time, time_bucket_start::date + close_time) --time bucket is in opening times
    AND EXISTS (SELECT station_uuid from prices p where p.station_uuid = st.station_id AND p.time >= param.start AND p.time <= param.end ) -- at least one event
),
flextime_active_buckets AS( --buckets with events in them
    SELECT
        station_id, city, always_open,
        time_bucket_start, time_bucket_end,
        start_time, end_time,
        p.diesel AS price,
        COALESCE(p.time,start_time)  as real_time 
    FROM flextime_active f LEFT JOIN (
        SELECT station_uuid, diesel, time
        FROM prices
        WHERE diesel_change IN (1, 3) AND time >= start_time AND time <= end_time
    ) p ON station_id = p.station_uuid
),
flextime_active_buckets_fixed AS (
    SELECT 
        station_id, city, always_open,
        time_bucket_start, time_bucket_end,
        start_time, end_time,
        COALESCE(
            p.price,
            LAG(p.price) OVER (PARTITION BY p.station_id ORDER BY p.real_time),
            LAG(p.price, 2) OVER (PARTITION BY p.station_id ORDER BY p.real_time),
            LAG(p.price, 3) OVER (PARTITION BY p.station_id ORDER BY p.real_time),
            LAG(p.price, 4) OVER (PARTITION BY p.station_id ORDER BY p.real_time),
            LAG(p.price, 5) OVER (PARTITION BY p.station_id ORDER BY p.real_time),
            LAG(p.price, 6) OVER (PARTITION BY p.station_id ORDER BY p.real_time),
            LAG(p.price, 7) OVER (PARTITION BY p.station_id ORDER BY p.real_time)
        ) AS price,
        p.real_time
    FROM flextime_active_buckets p 
)
SELECT * from flextime_active_buckets_fixed WHERE price IS NULL order by station_id, time_bucket_start, real_time;




























