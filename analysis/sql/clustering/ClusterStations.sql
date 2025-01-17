WITH param AS (
    SELECT :'dst_threshold'::int AS dst_threshold
),
top_cities AS ( --starts from the top cities
    SELECT 
        city,  COUNT(*) AS n_stations,
        AVG(latitude) AS lat, AVG(longitude) AS lon,
    FROM stations
    WHERE EXISTS (SELECT station_uuid from prices where station_uuid = id)
    GROUP BY city HAVING COUNT(*) > 30
    ORDER BY n_stations DESC
),
station_city_distances AS ( --stations with their possible cluster leaders (top cities close enough to the station)
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
    FROM stations s, param
    JOIN top_cities tc ON 
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
ranked_distances AS (
    SELECT 
        station_id, leader as cluster,
        ROW_NUMBER() OVER (PARTITION BY station_id ORDER BY distance_km ASC) AS rn
    FROM station_city_distances
),
clusters as ( --if a stations has more leaders, choose closest
    SELECT station_id, cluster FROM ranked_distances WHERE rn == 1
)
select * from clusters;