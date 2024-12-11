-- top cities in Germany by number of active stations (works on fixed stations dataset)
SELECT 
	city,
    COUNT(id) as n_stations
FROM 
	stations s
WHERE
	EXISTS(
        SELECT 1
		FROM prices p
        WHERE station_uuid = id
    )
GROUP BY city
HAVING COUNT(*) > 20
ORDER BY n_stations DESC;