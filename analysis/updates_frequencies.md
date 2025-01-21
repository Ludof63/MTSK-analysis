# Updates Frequencies Analysis

MTS-K records the history of price changes for fuel stations in Germany. One would like to analyze the price updates frequencies to answer the following question:

- How often are prices updated?

- How does the update frequency vary over time?

- How many updates per seconds are there on average?

  

> The SQL code blocks are meant to be examples runnable with `psql`

## `AvgUpdateFrq`: How often are prices updated?

For the goal of this analysis we can avoid differentiating between Always-Open and Flex-Time, as we would like to obtain statistics on our dataset more than having exact numbers for each station.

First of all, I have to consider each station individually. For each station, first find the time difference between price updates and then I can compute the average update frequency in minutes.

```sql
WITH param AS (
    SELECT  
        '2024-10-01'::TIMESTAMP AS start,
        '2024-10-30'::TIMESTAMP AS end,
), 
WITH price_differences AS (
    SELECT
        station_uuid, time,
        LAG(time) OVER (PARTITION BY station_uuid ORDER BY time) AS previous_time
    FROM prices, param
    WHERE (diesel_change IN (1,3) OR e5_change IN (1,3) OR e10_change IN (1,3)) --any price update
    AND time BETWEEN param.start and param.end
),
time_differences AS (
    SELECT station_uuid, EXTRACT(EPOCH FROM (time - previous_time)) AS sec_between_updates
    FROM price_differences
    WHERE previous_time IS NOT NULL
),
station_frq AS (
    SELECT station_uuid, AVG(sec_between_updates)/60 AS avg_min_between_updates
    FROM time_differences
    GROUP BY station_uuid
)
select * from station_frq;
```

To visualize the number of stations by average update frequency. We can extend the previous query to generate an "histogram" in SQL on the fly with

```postgresql
bounds AS (
    SELECT MIN(avg_min_between_updates) AS min_val, MAX(avg_min_between_updates) AS max_val
    FROM station_frq
),
bucket_counts AS (
    SELECT WIDTH_BUCKET(avg_min_between_updates, 0, bounds.max_val, 15) AS bucket,
            COUNT(*) AS station_count
    FROM station_frq, bounds
    GROUP BY bucket
)
SELECT
    FLOOR(((s.bucket-1) * (bounds.max_val / 15))) AS bucket_start,
    FLOOR(((s.bucket) * (bounds.max_val / 15))) AS bucket_end,
    COALESCE(c.station_count, 0) AS station_count,
FROM bounds,
    (SELECT GENERATE_SERIES(1, 15) AS bucket) s LEFT JOIN bucket_counts c ON s.bucket = c.bucket
ORDER BY s.bucket;
```

```postgresql
 bucket_start | bucket_end | station_count 
--------------+------------+---------------
            0 |       3467 |         14429
         3467 |       6935 |           363
         6935 |      10402 |           235
        10402 |      13870 |            36
        13870 |      17338 |             8
        17338 |      20805 |             0
        20805 |      24273 |             0
        24273 |      27740 |             0
        27740 |      31208 |             0
        31208 |      34676 |             0
        34676 |      38143 |             0
        38143 |      41611 |             0
        41611 |      45078 |             0
        45078 |      48546 |             0
        48546 |      52014 |             1
```

We notice that , if we do not consider outliers, most of the stations updates their prices within approximately 2 and half days (3467 minutes). Let's investigate the percentiles with

```postgresql
percentiles AS (
    SELECT
        percentile_cont(0.50) WITHIN GROUP (ORDER BY avg_min_between_updates) AS p50,
        percentile_cont(0.75) WITHIN GROUP (ORDER BY avg_min_between_updates) AS p75,
        percentile_cont(0.90) WITHIN GROUP (ORDER BY avg_min_between_updates) AS p90,
        percentile_cont(0.95) WITHIN GROUP (ORDER BY avg_min_between_updates) AS p95
    FROM station_frq
)
SELECT p50, p75, p90, p95 FROM percentiles;
```

```postgresql
       p50        |       p75        |       p90        |       p95        
------------------+------------------+------------------+------------------
 46.2764873472019 | 61.7124651318425 | 251.789584109597 | 2220.59984649122
```

The percentiles confirms that while most stations update relatively frequently, a small subset of stations have significantly longer update intervals. More than half of the stations update on average every 46 minutes or less. However, even considering p95 the prices are updates within 2 days (`2880 minutes`). Thus, we can consider 2 days a reasonable limit to consider a station inactive (accepting the loss of few outliers)



## `UpdatesDist`: How does the update frequency vary over time?





## How many updates per second?

We can compute the number of updates per second with the following query

```sql
WITH entries_per_second AS (
    SELECT date_trunc('second', time) AS datetime, COUNT(*) as n_entries
    FROM prices
    WHERE (diesel_change IN (1,3) OR e5_change IN (1,3) OR e10_change IN (1,3))
    GROUP BY datetime
)
SELECT SUM(n_entries) / EXTRACT(EPOCH FROM (max(datetime) - min(datetime))) as avg_updates_per_sec 
FROM entries_per_second;
```

```postgresql
 avg_updates_per_sec 
---------------------
    4.52335092878467
```

