# Real-Time Analysis (Grafana + Cedar)



## Insertions per Second

Let's start by analyzing how many insertions are happing per second. We can do that with

```sql
select count(*) / 10 as avg_insertions
from  prices
where time > (select max(time) from prices) - INTERVAL '10 seconds';
```

```sql
SELECT FORMAT(MAX(time), 'YYYY-MM-DD HH:mm:ss') FROM prices;

```





## Prices "Now"

We want to consider as now, the last update time we registered (as we're replicating a workload that happened in the past). We can reuse the [queries we use for one point in time](README.md), adapting just the parameters as follow:

```sql
WITH param AS (
    SELECT max(time) as time_t,
    (CASE WHEN EXTRACT(dow FROM time_t) = 0 THEN 6 ELSE EXTRACT(dow FROM time_t) -1 END ) as day_bit,
    '2 day'::INTERVAL as activity_interval
    from prices
)
```



I took a look at the query, and the problem was my query. If I use param, `stations JOIN ON top_cities ON (...)` or if I reformulate it just using where everything works. While here I'm using s`tations, param JOIN ON top_cities`, should it be syntax error?



Anyway, if you want to reproduce it you can download

- stations: https://raw.githubusercontent.com/Ludof63/MTSK-analysis/refs/heads/master/data/stations.csv

- schema:https://raw.githubusercontent.com/Ludof63/MTSK-analysis/refs/heads/master/sql/schema.sql

```bash
curl -L -o stations.csv https://raw.githubusercontent.com/Ludof63/MTSK-analysis/refs/heads/master/data/stations.csv
curl -L -o schema.sql https://raw.githubusercontent.com/Ludof63/MTSK-analysis/refs/heads/master/sql/schema.sql
```

Load the stations with 

```postgresql
\copy stations from 'stations.csv' with(format csv, delimiter ',', null '', header true);
```









- Price Now in:
  - Whole Germany
  - Top Cities
- 
- Prices on the map
- Given a point, where is more convenient to fuel up
- Number of open stations 