SELECT city, COUNT(distinct id) as n_stations, ARRAY_AGG(latitude) AS lats, ARRAY_AGG(longitude) AS lons
FROM stations s
WHERE EXISTS (SELECT station_uuid from prices p where p.station_uuid = s.id) -- avoid inactive stations
GROUP BY city HAVING COUNT(*) > 40; --at least 30 stations in the city

