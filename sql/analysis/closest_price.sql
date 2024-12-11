WITH param AS (
    SELECT  $1::TIMESTAMP  AS target_date,
            $2::INTERVAL AS interval_value,
),
WITH diesel_prices AS (
    SELECT p.station_uuid as id,
       p.diesel AS price,
       p.time AS time,
       ROW_NUMBER() OVER (
           PARTITION BY p.station_uuid
           ORDER BY ABS(EXTRACT(EPOCH FROM (p.time - param.target_date))) ASC
       ) AS rn
    FROM prices p
    JOIN param ON true
  	AND p.diesel_change IN (1, 3)
    AND p.time >= param.target_date - param.interval_value
  	AND p.time <= param.target_date + param.interval_value
)
SELECT s.id AS station_uuid,
       s.name as name,
       s.latitude as latitude,
       s.longitude as longitude,
       -- s.post_code as post_code,
      
       diesel_prices.price as diesel,
       diesel_prices.time as time
FROM stations s
JOIN diesel_prices ON s.id = diesel_prices.id AND diesel_prices.rn = 1
ORDER BY diesel;