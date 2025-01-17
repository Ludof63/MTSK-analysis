WITH clusters_centers AS (
    SELECT cluster, COUNT(id) as n_stations, AVG(latitude) AS lat, AVG(longitude) AS lon,
    FROM tmp_clusters, stations WHERE station_id = id GROUP BY cluster
)
SELECT 
    tc1.cluster as leader_a,
    tc2.cluster as leader_b,
    (
        2 * 6371 * ATAN2(
            SQRT(
                POWER(SIN(RADIANS(tc1.lat - tc2.lat) / 2), 2) +
                COS(RADIANS(tc2.lat)) * COS(RADIANS(tc1.lat)) *
                POWER(SIN(RADIANS(tc1.lon - tc2.lon) / 2), 2)
            ),
            SQRT(1 - (
                POWER(SIN(RADIANS(tc1.lat - tc2.lat) / 2), 2) +
                COS(RADIANS(tc2.lat)) * COS(RADIANS(tc1.lat)) *
                POWER(SIN(RADIANS(tc1.lon - tc2.lon) / 2), 2)
            ))
        )
    ) as dst,
FROM  clusters_centers tc1, clusters_centers tc2
WHERE tc1.cluster <> tc2.cluster ORDER BY dst ASC LIMIT 1;
