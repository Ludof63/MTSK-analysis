WITH param AS (
    SELECT '2024-01-31 17:00'::TIMESTAMP AS time_t, 
        (CASE WHEN EXTRACT(dow FROM time_t) = 0 THEN 6 ELSE EXTRACT(dow FROM time_t) -1 END ) as day_bit,
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
stats AS (
    SELECT AVG(price) AS avg_price, STDDEV(price) AS std_dev_price FROM curr_prices
),
prices_scores AS (
    SELECT p.*, (p.price - avg_price) / std_dev_price AS z_score
    FROM curr_prices p,stats
)
SELECT * FROM (
    SELECT brand, COUNT(*) n_stations, AVG(price) average_price
    FROM curr_prices
    WHERE brand <> ''
    GROUP BY brand 
    ORDER BY n_stations DESC LIMIT 10
) ORDER BY average_price;

select station_id, brand, city, latitude, longitude, price, z_score from prices_scores;


-- SELECT city, count(*) as n_open_station, avg(price) as average_price
-- FROM  curr_prices
-- GROUP BY city HAVING count(*) > 40
-- ORDER BY average_price;


-- order by n_open_station DESC limit 15;



-- SELECT short_cluster_name, count(*) as n_open_station, avg(price) as average_price
-- FROM curr_prices p, stations_clusters sc
-- WHERE p.station_id = sc.station_id
-- GROUP BY cluster_id, short_cluster_name
-- ORDER BY average_price;



-- select city, count(*) as n_open_station, avg(price) as average_price
-- from curr_prices
-- group by city
-- having count(*) > 30
-- order by n_open_station DESC limit 15;




