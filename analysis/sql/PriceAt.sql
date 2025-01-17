WITH param AS (
    SELECT 
    :'time'::TIMESTAMP AS time,
    (CASE WHEN EXTRACT(dow FROM time) = 0 THEN 6 ELSE EXTRACT(dow FROM time) -1 END ) as day_bit,
    '2 day'::INTERVAL as activity_interval
),
alwaysopen AS(
    SELECT s.id as station_id, s.always_open, city, brand, latitude, longitude
    FROM stations s, param
    WHERE s.always_open
    AND EXISTS (SELECT station_uuid from prices p where p.station_uuid = s.id AND p.time <= param.time AND p.time >= param.time - param.activity_interval) -- avoid inactive stations
),
flextime_open AS(
    SELECT
        station_id, false as always_open, city, brand, latitude, longitude
    FROM stations_times st, stations s, param
    WHERE st.station_id = s.id
    AND (st.days & (1 << (param.day_bit))) > 0 -- open day?
    AND time BETWEEN time::date + open_time AND time::date + close_time -- opening hours?
    AND EXISTS (SELECT station_uuid from prices p where p.station_uuid = s.id AND p.time <= param.time AND p.time >= param.time - param.activity_interval) -- avoid inactive stations
),
open_stations AS (
    SELECT * FROM alwaysopen
    UNION ALL -- alwaysopen and flextime stations do not overlap
    SELECT *  FROM flextime_open
),
open_curr_price AS (
    SELECT 
       open_stations.*, p.price, p.time
    FROM
        open_stations, param, 
        (
            SELECT diesel as price ,time
            FROM prices
            WHERE station_uuid = station_id AND time <= param.time 
            AND time >= param.time - activity_interval --limit
            AND diesel_change IN (1, 3)
            ORDER BY time DESC
            LIMIT 1
        ) p
), 
stats AS (
    SELECT AVG(price) AS avg_price, STDDEV(price) AS std_dev_price FROM open_curr_price
),
prices_z_scores AS (
    SELECT p.*, (p.price - avg_price) / std_dev_price AS z_score
    FROM open_curr_price p,stats
)
select * from prices_z_scores;
