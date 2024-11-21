WITH param AS (
    SELECT	%s::TEXT AS target_city,
            %s::TIMESTAMP AS target_date,
            %s::INTERVAL AS interval_value,
)SELECT station_uuid,
        name,
		latitude,
        post_code,
		longitude,
		time,
       	diesel AS diesel_price,
FROM (
    SELECT p.station_uuid,
           s.name,
           s.latitude,
    	   s.longitude,
           s.post_code,
           p.diesel,
           p.time,
           ROW_NUMBER() OVER (
               PARTITION BY p.station_uuid
               ORDER BY ABS(EXTRACT(EPOCH FROM (p.time - param.interval_value))) ASC
           ) AS rn
    FROM stations s
    JOIN prices p ON s.id = p.station_uuid
    JOIN param ON true
    WHERE s.city = param.target_city
      AND p.diesel_change IN (1, 3)
      AND p.time >= param.target_date - param.interval_value
      AND p.time <= param.target_date + param.interval_value
) AS ranked_prices
WHERE rn = 1;