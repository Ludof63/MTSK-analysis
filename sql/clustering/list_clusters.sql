SELECT 
    cluster,
    COUNT(id) as n_stations,
	ARRAY_AGG(latitude) AS lats,
    ARRAY_AGG(longitude) AS lons,
FROM stations_clusters
JOIN stations ON station_id = id
GROUP BY cluster
ORDER BY n_stations DESC;