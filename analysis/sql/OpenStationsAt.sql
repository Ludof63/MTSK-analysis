WITH param AS (
    SELECT max(time) AS time_t, (CASE WHEN EXTRACT(dow FROM time_t) = 0 THEN 6 ELSE EXTRACT(dow FROM time_t) -1 END ) as day_bit,
    FROM prices
),
alwaysopen AS(
    SELECT s.id as station_id, s.always_open, city, brand, latitude, longitude
    FROM stations s, param 
    WHERE s.always_open
        AND EXISTS (SELECT station_uuid FROM prices WHERE station_uuid = id AND time  BETWEEN time_t - INTERVAL '2 day' AND time_t) -- avoid inactive stations
),
flextime_open AS(
    SELECT station_id, false as always_open, city, brand, latitude, longitude
    FROM stations_times st, stations s, param
    WHERE st.station_id = s.id
        AND (st.days & (1 << (param.day_bit))) > 0 -- open day?
        AND time_t BETWEEN time_t::date + open_time AND time_t::date + close_time -- opening hours?
        AND EXISTS (SELECT station_uuid FROM prices WHERE station_uuid = id AND time  BETWEEN time_t - INTERVAL '2 day' AND time_t) -- avoid inactive stations
),
open_stations AS (
    SELECT * FROM alwaysopen UNION ALL SELECT *  FROM flextime_open
)
select count(station_id) as cnt from open_stations;
