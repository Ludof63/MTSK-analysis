WITH param AS (
    SELECT 	%s::TIMESTAMP AS target_date,
            %s::INTERVAL AS interval_value,
) SELECT station_uuid,
        name,
		latitude,
		longitude,
		time,
       	diesel AS diesel_price,
FROM (
    SELECT p.station_uuid,
    	   s.latitude,
    	   s.longitude,
           s.name,
           p.diesel,
           p.time,
           ROW_NUMBER() OVER (
               PARTITION BY p.station_uuid
               ORDER BY ABS(EXTRACT(EPOCH FROM (p.time - param.target_date))) ASC
           ) AS rn
    FROM stations s
    JOIN prices p ON s.id = p.station_uuid
    JOIN param ON true
    WHERE p.diesel_change IN (1, 3) 
		AND p.time >= param.target_date - param.interval_value
		AND p.time <= param.target_date + param.interval_value

) AS ranked_prices
WHERE rn = 1
ORDER BY time;