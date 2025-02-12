# An Analysis of Germany's Fuel Prices

The [Markttransparenzstelle für Kraftstoffe](https://www.bundeskartellamt.de/DE/Aufgaben/MarkttransparenzstelleFuerKraftstoffe/MTS-K_Infotext/mts-k_node.html) (MTS-K) collects the fuel prices for gas station all over Germany. A history of all price changes is available [here](https://dev.azure.com/tankerkoenig/tankerkoenig-data). This project contains:

- an analysis of the historical fuel prices in Germany 
- a client to replay the price changes (transactional workload)
  - a collection of Grafana dashboards to run a "real-time" (in the past) analysis

- scripts to download/prepare/ingest the dataset using a postgres-compliant relation db

[CedarDB](https://cedardb.com), a postgres-compliant [HTAP](https://en.wikipedia.org/wiki/Hybrid_transactional/analytical_processing) relational database, allows us to use one db for both the data analysis and the transactional workload.

You can **take a look at the analysis [here](https://ludof63.github.io/MTSK-analysis/analysis/).** Or you can follow the next steps and run some queries on the dataset yourself.

## Getting Started

1. ### Download the Dataset

   The dataset is dived in:

   - **Stations**: this repository contains an already prepared version of the stations in `data/` (updated weekly, max 1-week lag, more details [here](./scripts/data_preparation.md)) 

   - Prices: the history of price updates. You can download it with

     ```bash
     ./scripts/download.sh -p 2024/01 2024/12
     ```

     This will download prices from 2024/01 to 2024/12, saving them in `data/prices/`, around 13 GB uncompressed ([ script's documentation](./scripts/README.md))

2. ### Start the Database

   Assuming you have [CedarDB image](https://cedardb.com/docs/getting_started/running_docker_image/) locally as `cedardb`.

   ```bash
   docker compose up -d
   ```

   Starts CedarDB and [Grafana](https://grafana.com/). You can access Grafana at http://localhost:3000/ with username `admin` and password `admin`. 

   > You can stop the containers with `docker compose down`. By default the database is persisted with a docker volume, if you want a fresh start run `docker compose down -v` to remove the volumes

3. ### Load the data

   The next step is to load the data in the db. In particular, we need to:

   - create the schema (`sql/schema.sql`) 
   - load stations and stations' times 
   - load a chunk of the prices

   You can either do manually, or run the following

   ```bash
   ./scripts/load.sh -c -s -p 2024/01 2024/06
   ```

   `-c` creates the schema, `-s` loads stations and their times, `-p 2024/01 2024/06` loads prices from `data/prices/` in `[2024/01/01, 2024/06/01)`

4. ### Replay Transactional Workload (`optional`)

   Now you are ready to query the datasets. However, you can also replay the remaining part of the prices updates as a transactional workload using the python client in `scripts/replay/`, that you can run with

   ```bash
   docker compose run -it --rm --name replayer replayer -p /prices -s 60
   ```

   The client replays the workload (inserting price updates by time) starting from the event after the latest event already in the database. In particular:

   - `-p /prices` is where to look for prices files (the container has a volume ./data/prices:/prices, configured [here](docker-compose.yml));
   - `-s 60` is the factor speed at which the dataset will be replayed (60 = executing every second one minute of transactions)

5. ### Query the data

   To run queries connect to the db with

   ```bash
   psql 'host=localhost user=client dbname=client password=client'
   ```

   > If you don't have psql locally you can always use
   >
   > ```bash
   > docker exec -it cedar psql 'user=client dbname=client password=client'
   > ```

   #### Some examples

   - Check the prices chunk you've loaded

     ```sql
     select min(time)as first , max(time) as  last, count(*) as n_events from prices;
     ```

   - Remove wrong prices

     ```sql
     DELETE 
     FROM prices 
     WHERE (diesel_change in (1,3) and diesel < 0) OR (e5_change in (1,3) and e5 < 0) OR (e10_change in (1,3) and e10 < 0);
     ```

   - Top cities by number of stations (active one)

     ```sql
     SELECT city, COUNT(distinct id) as n_stations, AVG(latitude) AS latitude, AVG(longitude) AS longitude
     FROM stations s
     WHERE EXISTS (SELECT station_uuid from prices p where p.station_uuid = s.id) -- avoid inactive stations
     GROUP BY city HAVING COUNT(*) > 40; --at least 30 stations in the city
     ```

   - Latest ("current" if you're replaying the dataset) average diesel price over the whole country

     ```sql
     WITH param AS (
         SELECT max(time) AS time_t, 
         (CASE WHEN EXTRACT(dow FROM time_t) = 0 THEN 6 ELSE EXTRACT(dow FROM time_t) -1 END ) as day_bit,
         FROM prices
     ),
     active_stations AS(
         SELECT s.id as station_id, s.*
         FROM param, stations s 
         WHERE first_active <= time_t AND
         EXISTS (SELECT station_uuid from prices p where p.station_uuid = s.id AND time BETWEEN time_t - INTERVAL '3 day' AND time_t)-- avoid inactive stations
     ), 
     alwaysopen AS(
         SELECT s.* FROM active_stations s WHERE s.always_open 
     ),
     flextime_open AS(
         SELECT s.*
         FROM param, stations_times st, active_stations s
         WHERE st.station_id = s.station_id
             AND (days & (1 << (day_bit))) > 0 -- open day?
             AND time_t BETWEEN time_t::date + open_time AND time_t::date + close_time -- opening hours?
     ),
     open_stations AS (
         SELECT * FROM alwaysopen UNION ALL SELECT *  FROM flextime_open
     ),
     open_curr_price AS (
         SELECT open_stations.*, p.price, p.time
         FROM open_stations, param, 
             (
                 SELECT diesel as price ,time
                 FROM prices
                 WHERE station_uuid = station_id AND time <= time_t
                 AND time >= time_t - INTERVAL '2 day' --limit
                 AND diesel_change IN (1, 3)
                 ORDER BY time DESC
                 LIMIT 1
             ) p
     ), 
     stats AS (
         SELECT AVG(price) AS avg_price, STDDEV(price) AS std_dev_price FROM open_curr_price
     ) -----------
     -- Average Price Now
     SELECT avg_price from stats;
     ```



If you want to continue with a more in depth exploration of the dataset you take a look at the [analysis](https://ludof63.github.io/MTSK-analysis/analysis/).

