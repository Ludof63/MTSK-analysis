SELECT station_uuid,
       diesel AS diesel_price,
FROM (
    SELECT p.station_uuid,
           s.name,
           p.diesel,
           p.time,
           ROW_NUMBER() OVER (
               PARTITION BY p.station_uuid
               ORDER BY ABS(EXTRACT(EPOCH FROM (p.time - %s))) ASC
           ) AS rn
    FROM stations s
    JOIN prices p ON s.id = p.station_uuid
    WHERE s.city = %s
      AND p.diesel_change IN (1, 3)
) AS ranked_prices
WHERE rn = 1;