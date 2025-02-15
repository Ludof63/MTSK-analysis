WITH param AS (
    SELECT max(time) AS time_t, 
    (CASE WHEN EXTRACT(dow FROM time_t) = 0 THEN 6 ELSE EXTRACT(dow FROM time_t) -1 END ) as day_bit,
    FROM prices
),
active_stations AS(
    SELECT s.id as station_id, s.*
    FROM param, stations s 
    WHERE first_active <= time_t AND
    EXISTS (SELECT station_uuid from prices p where p.station_uuid = s.id AND time BETWEEN time_t - INTERVAL '3 day' AND time_t)-- avoid inactive stations
), 
alwaysopen AS(
    SELECT s.* FROM active_stations s WHERE s.always_open 
),
flextime AS(
    SELECT s.*
    FROM param, stations_times st, active_stations s
    WHERE st.station_id = s.station_id
        AND (days & (1 << (day_bit))) > 0 -- open day?
        AND time_t BETWEEN time_t::date + open_time AND time_t::date + close_time -- opening hours?
),
open_stations AS (
    SELECT * FROM alwaysopen UNION ALL SELECT *  FROM flextime
),
open_curr_price AS (
    SELECT open_stations.*, p.price, p.time
    FROM open_stations, param, 
        (
            SELECT diesel as price ,time
            FROM prices
            WHERE station_uuid = station_id AND time <= time_t
            AND time >= time_t - INTERVAL '2 day' --limit
            AND diesel_change IN (1, 3)
            ORDER BY time DESC
            LIMIT 1
        ) p
), 
stats AS (
    SELECT AVG(price) AS avg_price, STDDEV(price) AS std_dev_price FROM open_curr_price
) -----------
-- Average Price Now
SELECT avg_price from stats;


-- Open Stations Now
SELECT COUNT(*) from open_stations;



-- Open Stations Distribution
SELECT 
 (select count(station_id) from flextime_open) as n_flextime,
 (select count(station_id) from alwaysopen) as n_alwaysopen;

