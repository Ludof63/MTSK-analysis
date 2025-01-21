# MTS-K dataset: analysis

MTS-K records the history of price changes for fuel stations in Germany. In this document we get started with a basic analysis, focusing on a point in time. While:

- an analysis of price updates frequencies can be found [here](updates_frequencies.md)
- an analysis of fuel prices over time can be found [here](time-series_analysis.md)

> The SQL code blocks are meant to be examples runnable with `psql`

> When I refer to scripts they can be found in the folder `scripts/`, while SQL queries can be found in `sql/`

## Starting Point

As we will use mainly SQL for this analysis I suggest to take a look at the [schema](../sql/MTS-K_schema.sql) that consists in 3 tables:

- **prices**: each entry is a price change for a certain fuels for a certain station
- **stations**: information about fuel stations
- **stations_times**: opening hours for each station

Important notes:

- **A price `p` for a fuel `f` at a certain station `s` is valid until the next (in time) price event for `f` for `s`.**
- For a fuel `f` I should only consider the price events with `f_change IN (1,3)`. From now on when I refer to a price event I consider it a valid one.
- We can classify the stations in **Always-Open** stations and **Flex-Time** stations. The Flex-Time stations have entries in `station_times`



## Stations Open at a Certain Time: `OpenStationsAt`

Let's start by analyzing fuel prices at a point in time. We *set the parameter `time`* (psql variable),  we will use it for the following queries

```postgresql
\set time '2024-11-01 12:00'
```

In this first example we count count the open stations. To achieve that correctly, we have to differentiate between Always-Open and Flex-Time stations. Additionally, the  stations dataset is incremental, so there may be inactive stations in it. To avoid counting inactive stations we **consider active only the stations with an event in the previous 48 hours** (see [updates frequency analysis](updates_frequencies.md)).

```postgresql
WITH param AS (
    SELECT 
    :'time'::TIMESTAMP AS time,
    (CASE WHEN EXTRACT(dow FROM time) = 0 THEN 6 ELSE EXTRACT(dow FROM time) -1 END ) as day_bit,
    '2 day'::INTERVAL as activity_interval
),
alwaysopen AS(
    SELECT s.id as station_id, s.always_open, city, brand, latitude, longitude
    FROM stations s, param
    WHERE s.always_open
    AND EXISTS (SELECT station_uuid from prices p where p.station_uuid = s.id AND p.time <= param.time AND p.time >= param.time - param.activity_interval) -- avoid inactive stations
),
flextime_open AS(
    SELECT
        station_id, false as always_open, city, brand, latitude, longitude
    FROM stations_times st, stations s, param
    WHERE st.station_id = s.id
    AND (st.days & (1 << (param.day_bit))) > 0 -- open day?
    AND time BETWEEN time::date + open_time AND time::date + close_time -- opening hours?
    AND EXISTS (SELECT station_uuid from prices p where p.station_uuid = s.id AND p.time <= param.time AND p.time >= param.time - param.activity_interval) -- avoid inactive stations
),
open_stations AS (
    SELECT * FROM alwaysopen
    UNION ALL -- alwaysopen and flextime stations do not overlap
    SELECT *  FROM flextime_open
)
select count(station_id) as cnt from open_stations;
```

## Price at a Certain Time: `PriceAt`

To get the (diesel) prices at a certain point in time we can extend `OpenStationsAt` 

```postgresql
open_curr_price AS (
    SELECT 
       open_stations.*, p.price, p.time
    FROM
        open_stations, param, 
        (
            SELECT diesel as price ,time
            FROM prices
            WHERE station_uuid = station_id AND time <= param.time 
            AND time >= param.time - activity_interval --limit
            AND diesel_change IN (1, 3)
            ORDER BY time DESC
            LIMIT 1
        ) p
)
select avg(price) from open_curr_price;
```

In this example we are computing the average price over the whole country at `2024-11-01 12:00:00`

### Price distribution

Now using the `diesel` prices at `2024-11-01 12:00:00`, let's plot using `prices_distribution.py` the distribution over the station over the prices.<img src="plots/prices_dist_diesel.png" style="zoom:72%;" />

We notice that most of the prices are concentrated around the average (`1.54`), while there are few outliers and some of them registered crazy expensive prices. We can check the number of outliers using `z_score` (considering outliers those stations for which `abs(z_score) > 3`). 

```postgresql
stats AS (
    SELECT AVG(price) AS avg_price, STDDEV(price) AS std_dev_price FROM open_curr_price
),
z_scores AS (
    SELECT p.*, (p.price - avg_price) / std_dev_price AS z_score
    FROM open_curr_price p,stats
)
SELECT 
    COUNT(*) AS total_count,
    SUM(CASE WHEN ABS(z_score) > 3 THEN 1 ELSE 0 END) AS outlier_count
FROM z_scores;
```

```postgresql
 total_count | outlier_count 
-------------+---------------
       15037 |           333
```

Around 2% of the stations report outlier prices. While if we do not consider this outliers the distribution would look like
<img src="plots/prices_dist_diesel_no_outliers.png" style="zoom: 67%;" />

### Distribution of Prices on Germany Map

Now it would be interesting to plot the prices at a current time on the map of Germany. The stations are plot with a color base on their deviation from the mean, the mean doesn't consider outliers that are reported as black points.

<iframe src="plots/prices_on_map.html" width="100%" height="600" style="border: 1px solid #ccc;"></iframe>

> The map `prices_on_map.html` was generated using `prices_map.py` for `diesel` and `e5` at `2024-11-01 12:00:00` (the rendering of the html requires around 10s).
>

From the map one can notice that:

- **basically all the outliers are located on autobahn**
- As we could expect, there seems to be a **correlation between fuel prices of stations in a local area**. 
- As for the diesel, overall one can see that cities (and their surroundings) in the West of Germany are cheaper that those in the South/Nord - Est

### Compare Brands 

We can also compare the top 10 brands (by number of stations), by extending `PriceAt` with

```sql
select brand, COUNT(*) n_stations, AVG(price) avg_price
from open_curr_price where brand <> ''
group by brand order by n_stations DESC limit 10;
```

If we plot is with `prices_brands.py` we get

<img src="plots/prices_brand_diesel.png" style="zoom:72%;" />

We notice that while there are differences, those are contained, probably also due to the average across the entire country.

## Comparing Cities by Fuel Prices

### Group Stations by City Name

To compare fuel prices across cities we first have to solve the problem of **identifying the stations that belong to a city**. We can use the city attribute of stations as a starting point, after having prepared the dataset (more information in `/scripts/data_prep`).

We can extend `PriceAt` with the following aggregation

```sql
top_cities AS(
    SELECT city, COUNT(*) n_stations, AVG(price) avg_price
    FROM open_curr_price
    GROUP BY city ORDER BY n_stations DESC limit 10
)
select city, n_stations, avg_price::NUMERIC(10, 3) as avg_price
from top_cities order by avg_price;
```

```postgresql
   city    | n_stations | avg_price 
-----------+------------+-----------
 Bremen    |         75 |     1.499
 Köln      |        106 |     1.512
 Essen     |         67 |     1.516
 Berlin    |        274 |     1.517
 Dortmund  |         88 |     1.520
 Stuttgart |         70 |     1.528
 Hamburg   |        207 |     1.539
 München   |        129 |     1.549
 Nürnberg  |         74 |     1.563
 Hannover  |         71 |     1.580
```

After obtaining this first comparison between cities, we should ask ourselves what are we considering as a "city". Let's start by plotting the stations of each city on a map:

<iframe src="plots/cities_map.html" width="100%" height="600" style="border: 1px solid #ccc;"></iframe>

The map is generated using `cities_map.py` with the following query (`TopCitiesStations.sql`):

```postgresql
SELECT city, COUNT(distinct id) as n_stations, ARRAY_AGG(latitude) AS lats, ARRAY_AGG(longitude) AS lons
FROM stations s
WHERE EXISTS (SELECT station_uuid from prices p where p.station_uuid = s.id) -- avoid inactive stations
GROUP BY city HAVING COUNT(*) > 40; --at least 30 stations in the city
```

 From the map we can notice that grouping by city we're in reality just considering the stations in the city center. While, one would like to group stations in the local area of a city (city center and surroundings). However, the MTS-K dataset doesn't help us on, so we have to compute ourselves some kind of **clustering of the stations by city area**.

### Clustering Stations by City Areas

The most important question we have to ask ourselves is what is a "city area"?

As the answer to this question depends on the city topology, I decided to simplify the city area  as the area of a circle of `dst_threshold` km with center the city center.

```postgresql
\set dst_threshold 30
```

The idea is to start from the biggest cities' centers. We consider each of this city as a "cluster leader". Each station is the assigned to the cluster of the closest big city (if it lies within `dst_threshold` from a big city). We can achieve this using the following query (`ClusterStations`):

```postgresql
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
```

Now we can aggregate the clusters as we did for the city names.

```postgresql
SELECT 
    cluster, COUNT(id) as n_stations,
	ARRAY_AGG(latitude) AS lats, ARRAY_AGG(longitude) AS lons,
FROM clusters, stations WHERE station_id = id
GROUP BY cluster ORDER BY n_stations DESC;
```

And plot it on a map with python (`cluster_stations.py`).

<iframe src="plots/stations_clusters.html" width="100%" height="600" style="border: 1px solid #ccc;"></iframe>

While for isolated cities like Berlin and Nuremberg this is enough, we notice that there are clusters close too each other that we would like to "merge".

I think of the merge phase as an iterative process in which each iteration merges the close-enough clusters until there are not, close-enough clusters.  While one could do that using only SQL, I was lazy and decided to do this iterative process combining python and SQL. I start by storing the result of `ClusterStations` in a temporary table `tmp_clusters`. Then in each iteration I get the closest cluster with

```sql
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
```

And in python I check if dst is close enough, if so I merge the two clusters with a simple update statement 

```python
f"UPDATE {TMP_TABLE} SET cluster = '{leader_a} , {leader_b}' WHERE cluster = '{leader_a}' OR cluster = '{leader_b}';"
```

The python code is in `cluster_stations.py`. And the clusters we obtain after the merging phase look like 

<iframe src="plots/stations_clusters_merged.html" width="100%" height="600" style="border: 1px solid #ccc;"></iframe>

Assuming we store our final clusters' mappings in `stations_clusters`, we can extend `PriceAt` with a similar aggregation to the one for city names

```postgresql
clusters AS(
    SELECT cluster, COUNT(*) n_stations, AVG(price) avg_price
    FROM open_curr_price p ,stations_clusters c WHERE p.station_id = c.station_id
    GROUP BY cluster ORDER BY n_stations DESC -- limit 10
)
select cluster, n_stations, avg_price::NUMERIC(10, 3) AS avg_price
from clusters order by avg_price;
```

```postgresql
                        cluster                        | n_stations | avg_price 
-------------------------------------------------------+------------+-----------
 Chemnitz                                              |        127 |     1.514
 Köln, Bonn, Aachen                                    |        563 |     1.516
 Mannheim, Karlsruhe                                   |        543 |     1.519
 Münster, Hamm, Bielefeld, Osnabrück                   |        700 |     1.519
 Oldenburg, Bremen                                     |        309 |     1.522
 Berlin                                                |        397 |     1.523
 Regensburg                                            |        105 |     1.526
 Hagen, Dortmund, Gelsenkirchen, Essen, Bochum, Mön... |       1271 |     1.527
 Magdeburg                                             |         98 |     1.534
 Frankfurt am Main, Wiesbaden                          |        507 |     1.540
 Leipzig                                               |        152 |     1.545
 Stuttgart                                             |        374 |     1.545
 Hamburg, Lübeck                                       |        483 |     1.551
 Augsburg, München                                     |        415 |     1.552
 Dresden                                               |        110 |     1.560
 Kiel                                                  |         96 |     1.568
 Kassel                                                |        124 |     1.571
 Nürnberg                                              |        230 |     1.575
 Hannover, Braunschweig                                |        372 |     1.576
```

Where I limited the cluster label length to 50 chars , the only label cut also includes `Mönchengladbach, Duisburg, Krefeld, Düsseldorf, Wuppertal`. 

We can observe how a city area generally has prices similar to those of the city center.
