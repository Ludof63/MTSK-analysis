WITH param AS (
    SELECT (select max(time) from prices) AS time_t, 
    (CASE WHEN EXTRACT(dow FROM time_t) = 0 THEN 6 ELSE EXTRACT(dow FROM time_t) -1 END ) as day_bit,
    52.50383 as lat, 13.3936 as lon, 30 AS dst_threshold
    FROM prices
),
close_enough_stations AS (
    SELECT s.*
    FROM param, ( 
        SELECT s.*, haversine_dst(lat, lon, s.latitude, s.longitude) as dst_km
        FROM stations s
    ) as s
    WHERE dst_km <= dst_threshold
),
active_stations AS(
    SELECT s.id as station_id, s.*
    FROM param, close_enough_stations s 
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
    SELECT * FROM alwaysopen UNION ALL SELECT * FROM flextime
),
curr_prices AS (
    SELECT open_stations.*, p.price, p.time
    FROM open_stations, param, (
            SELECT diesel as price ,time
            FROM prices
            WHERE station_uuid = station_id AND time <= time_t 
            AND time >= time_t - INTERVAL '3 day'
            AND diesel_change IN (1, 3)
            ORDER BY time DESC
            LIMIT 1
        ) p
),
rankings AS (
    SELECT s.*,  RANK() OVER (ORDER BY total_cost ASC) AS position
    FROM (
        SELECT pr.*, (price * 40) + (dst_km * ((7/100)*price)) as total_cost
        FROM curr_prices pr
        ) as s
)
SELECT station_id, brand, latitude, longitude, price, dst_km, total_cost, position
FROM rankings;