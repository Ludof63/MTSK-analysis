WITH param AS (
    SELECT 'hour' AS time_granularity,
)
SELECT 
    date_trunc(time_granularity, p.time) AS datetime,
    COUNT(DISTINCT s.id) n_stations,
    AVG(p.diesel) as avg_diesel_price
FROM 
	stations s JOIN prices p ON s.id = p.station_uuid 
    JOIN param ON true
WHERE
	p.diesel_change IN (1, 3) 
    AND p.time >= param.start AND p.time <= param.end
GROUP BY
    date_trunc(time_granularity, p.time)
ORDER BY 
    datetime;


WITH param AS (
    SELECT 'hour' AS time_granularity,
            '2024-01-01'::TIMESTAMP  AS start,
            '2024-11-30'::TIMESTAMP  AS end
)
SELECT 
    date_trunc(time_granularity, p.time) AS datetime,
    COUNT(distinct s.id) n_stations,
FROM 
	stations s JOIN prices p ON s.id = p.station_uuid 
    JOIN param ON true
WHERE
	p.diesel_change IN (1, 3) 
    AND p.time >= param.start AND p.time <= param.end
GROUP BY
    date_trunc(time_granularity, p.time)
ORDER BY 
    datetime;