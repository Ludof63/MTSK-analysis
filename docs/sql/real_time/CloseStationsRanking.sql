WITH param AS (
    SELECT (select max(time) from prices) AS time_t, 
    (CASE WHEN EXTRACT(dow FROM time_t) = 0 THEN 6 ELSE EXTRACT(dow FROM time_t) -1 END ) as day_bit,
    52.50383 as lat, 13.3936 as lon, 30 AS dst_threshold
    FROM prices
),
close_enough_stations AS (
    SELECT s.*
    FROM param, ( 
        SELECT s.*, 2 * 6371 * ATAN2(
                SQRT(
                    POWER(SIN(RADIANS(lat - s.latitude) / 2), 2) +
                    COS(RADIANS(s.latitude)) * COS(RADIANS(lat)) *
                    POWER(SIN(RADIANS(lon - s.longitude) / 2), 2)
                ),
                SQRT(1 - (
                    POWER(SIN(RADIANS(lat - s.latitude) / 2), 2) +
                    COS(RADIANS(s.latitude)) * COS(RADIANS(lat)) *
                    POWER(SIN(RADIANS(lon - s.longitude) / 2), 2)
                ))
            ) AS dst_km
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













$latitude as lat, $longitude as lon, $dst_threshold AS dst_threshold


alwaysopen AS(
    SELECT s.* FROM active_stations s WHERE s.always_open 
),
flextime_open AS(
    SELECT s.*
    FROM param, stations_times st, active_stations s
    WHERE st.station_id = s.station_id
        AND (days & (1 << (day_bit))) > 0 -- open day?
        AND time_t BETWEEN time_t::date + open_time AND time_t::date + close_time -- opening hours?
),
open_stations AS (
    SELECT * FROM alwaysopen UNION ALL SELECT *  FROM flextime_open
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

-- Open Stations In The Area
SELECT COUNT(*) from open_stations;

-- AVG Prices
SELECT avg_price from stats;

-- Prices In The Area
,prices_z_scores AS (
    SELECT p.*, (p.price - avg_price) / std_dev_price AS z_score
    FROM open_curr_price p,stats
)
SELECT station_id, brand, latitude, longitude, price, dst_km, z_score
FROM prices_z_scores;

--Best place to fuel up
,rankings AS (
    SELECT s.*,  RANK() OVER (ORDER BY total_cost ASC) AS position
    FROM (
        SELECT pr.*, (price * 40) + (dst_km * ((7/100)*price)) as total_cost
        FROM open_curr_price pr
        ) as s
)
SELECT station_id, brand, latitude, longitude, price, dst_km, total_cost, position
FROM rankings;


-- Top Brands In The Area
SELECT brand, avg(price) as avg_price, COUNT(*) n_stations
FROM (
    SELECT pr.*, (price * 40) + (dst_km * ((7/100)*price)) as total_cost
    FROM open_curr_price pr
    )
WHERE brand <> ''
GROUP BY brand
ORDER BY n_stations DESC LIMIT 10;