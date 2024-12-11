-- starting from the biggest cities, each stations ends up in the closer biggest city cluster
CREATE TABLE stations_clusters AS
WITH param AS (
    SELECT $1::int  AS dst_threshold
),
top_cities AS (
    SELECT 
        city, 
        AVG(latitude) AS lat,
        AVG(longitude) AS lon,
        COUNT(id) AS n_stations
    FROM 
        stations
    WHERE EXISTS (SELECT station_uuid from prices where station_uuid = id)
    GROUP BY city
    HAVING COUNT(id) > 30
    ORDER BY n_stations DESC
    --LIMIT 20
),
station_city_distances AS (
    SELECT 
        s.id AS station_id, 
        tc.city AS leader,
        2 * 6371 * ATAN2(
            SQRT(
                POWER(SIN(RADIANS(tc.lat - s.latitude) / 2), 2) +
                COS(RADIANS(s.latitude)) * COS(RADIANS(tc.lat)) *
                POWER(SIN(RADIANS(tc.lon - s.longitude) / 2), 2)
            ),
            SQRT(1 - (
                POWER(SIN(RADIANS(tc.lat - s.latitude) / 2), 2) +
                COS(RADIANS(s.latitude)) * COS(RADIANS(tc.lat)) *
                POWER(SIN(RADIANS(tc.lon - s.longitude) / 2), 2)
            ))
        ) AS distance_km
    FROM 
        stations s
    JOIN param ON true
    JOIN 
        top_cities tc
    ON 
        (
            2 * 6371 * ATAN2(
                SQRT(
                    POWER(SIN(RADIANS(tc.lat - s.latitude) / 2), 2) +
                    COS(RADIANS(s.latitude)) * COS(RADIANS(tc.lat)) *
                    POWER(SIN(RADIANS(tc.lon - s.longitude) / 2), 2)
                ),
                SQRT(1 - (
                    POWER(SIN(RADIANS(tc.lat - s.latitude) / 2), 2) +
                    COS(RADIANS(s.latitude)) * COS(RADIANS(tc.lat)) *
                    POWER(SIN(RADIANS(tc.lon - s.longitude) / 2), 2)
                ))
            )
        ) <= dst_threshold
),
ranked_distances AS ( --for points with more possible clusters, assign to closest (first), for the moment
    SELECT 
        station_id, 
        leader as cluster,
        ROW_NUMBER() OVER (PARTITION BY station_id ORDER BY distance_km ASC) AS rn
    FROM 
        station_city_distances
)
SELECT station_id, cluster
FROM ranked_distances
WHERE rn == 1;