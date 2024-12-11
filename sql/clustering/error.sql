WITH RECURSIVE param AS (
    SELECT '15'::int  AS dst_threshold
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
        -- 2 * 6371 * ATAN2(
        --     SQRT(
        --         POWER(SIN(RADIANS(tc.lat - s.latitude) / 2), 2) +
        --         COS(RADIANS(s.latitude)) * COS(RADIANS(tc.lat)) *
        --         POWER(SIN(RADIANS(tc.lon - s.longitude) / 2), 2)
        --     ),
        --     SQRT(1 - (
        --         POWER(SIN(RADIANS(tc.lat - s.latitude) / 2), 2) +
        --         COS(RADIANS(s.latitude)) * COS(RADIANS(tc.lat)) *
        --         POWER(SIN(RADIANS(tc.lon - s.longitude) / 2), 2)
        --     ))
        -- ) AS distance_km
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
cluster_connections AS(
    SELECT DISTINCT
        sc1.leader AS leader_a, 
        sc2.leader AS leader_b
    FROM 
        station_city_distances sc1
    JOIN 
        station_city_distances sc2 
    ON 
        sc1.station_id = sc2.station_id AND sc1.leader <> sc2.leader
),
merged_clusters AS (    -- recursive 'connected components'
    SELECT 
        leader_a,
        leader_b
    FROM  cluster_connections

    UNION
    SELECT 
        mc.leader_a, 
        cc.leader_b, 
    FROM 
        cluster_connections cc
    JOIN 
        merged_clusters mc 
    ON 
        (cc.leader_a = mc.leader_b and cc.leader_a <> mc.leader_a)
),
merged_clusters_maps AS (
    SELECT leader_a, string_agg(leader_b, ',' order by leader_b) as cluster FROM merged_clusters GROUP BY leader_a
),
final_clusters AS (
    SELECT DISTINCT station_id,
    CASE
            WHEN leader IN (SELECT leader_a FROM merged_clusters_maps)
            THEN (SELECT m.cluster FROM merged_clusters_maps m WHERE leader_a = leader)
            ELSE leader
    END AS cluster

    FROM station_city_distances 
),
stations_clusters as (
    SELECT s.*, cluster
    FROM stations s LEFT OUTER JOIN  final_clusters ON s.id = station_id
)
SELECT 
    cluster,
    COUNT(id) as n_stations,
	--ARRAY_AGG(latitude) AS lats,
    --ARRAY_AGG(longitude) AS lons,
FROM stations_clusters
WHERE cluster is not NULL
GROUP BY cluster
ORDER BY n_stations DESC;
















2024-12-11 10:13:20.731077566 UTC       DEBUG1:  <- Query: WITH RECURSIVE param AS (
    SELECT '15'::int  AS dst_threshold
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
        -- 2 * 6371 * ATAN2(
        --     SQRT(
        --         POWER(SIN(RADIANS(tc.lat - s.latitude) / 2), 2) +
        --         COS(RADIANS(s.latitude)) * COS(RADIANS(tc.lat)) *
        --         POWER(SIN(RADIANS(tc.lon - s.longitude) / 2), 2)
        --     ),
        --     SQRT(1 - (
        --         POWER(SIN(RADIANS(tc.lat - s.latitude) / 2), 2) +
        --         COS(RADIANS(s.latitude)) * COS(RADIANS(tc.lat)) *
        --         POWER(SIN(RADIANS(tc.lon - s.longitude) / 2), 2)
        --     ))
        -- ) AS distance_km
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
cluster_connections AS(
    SELECT DISTINCT
        sc1.leader AS leader_a, 
        sc2.leader AS leader_b
    FROM 
        station_city_distances sc1
    JOIN 
        station_city_distances sc2 
    ON 
        sc1.station_id = sc2.station_id AND sc1.leader <> sc2.leader
),
merged_clusters AS (    -- recursive 'connected components'
    SELECT 
        leader_a,
        leader_b
    FROM  cluster_connections

    UNION
    SELECT 
        mc.leader_a, 
        cc.leader_b, 
    FROM 
        cluster_connections cc
    JOIN 
        merged_clusters mc 
    ON 
        (cc.leader_a = mc.leader_b and cc.leader_a <> mc.leader_a)
),
merged_clusters_maps AS (
    SELECT leader_a, string_agg(leader_b, ',' order by leader_b) as cluster FROM merged_clusters GROUP BY leader_a
),
final_clusters AS (
    SELECT DISTINCT station_id,
    CASE
            WHEN leader IN (SELECT leader_a FROM merged_clusters_maps)
            THEN (SELECT m.cluster FROM merged_clusters_maps m WHERE leader_a = leader)
            ELSE leader
    END AS cluster

    FROM station_city_distances 
),
stations_clusters as (
    SELECT s.*, cluster
    FROM stations s LEFT OUTER JOIN  final_clusters ON s.id = station_id
)
SELECT 
    cluster,
    COUNT(id) as n_stations,
        --ARRAY_AGG(latitude) AS lats,
    --ARRAY_AGG(longitude) AS lons,
FROM stations_clusters
WHERE cluster is not NULL
GROUP BY cluster
ORDER BY n_stations DESC;
2024-12-11 10:13:21.214906906 UTC       LOG:     server 0x209c33e
server 0x209c848
libc.so.6 0x45250
server 0x238c200
server 0x220bca5
server 0x20addc4
server 0x20b021b
server 0x20b120b
server 0x20ac27b
server 0x20a679c
libstdc++.so.6 0xe8ea4
libc.so.6 0xa1e2e
libc.so.6 0x133834