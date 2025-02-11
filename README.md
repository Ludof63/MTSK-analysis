# An Analysis of Germany's Fuel Prices

The [Markttransparenzstelle für Kraftstoffe](https://www.bundeskartellamt.de/DE/Aufgaben/MarkttransparenzstelleFuerKraftstoffe/MTS-K_Infotext/mts-k_node.html) (MTS-K) collects the fuel prices for gas station all over Germany. A history of all price changes is available [here](https://dev.azure.com/tankerkoenig/tankerkoenig-data). This project contains:

- scripts to download/prepare/ingest the dataset into a relational database

- an analysis of the historical fuel prices in Germany using SQL (+ Python and Grafana for plotting)
- a client that replicates the workload of prices changes and real-time dashboards in Grafana

We use [CedarDB](https://cedardb.com), an HTAP relational database that allows us to execute at the same time OLAP (analytical queries) and OLTP (transactions).

You can **take a look at the analysis [here](https://ludof63.github.io/MTSK-analysis/analysis/).** Or you can run some queries on the dataset yourself, following the next steps.

## Getting Started

1. ### Download the Dataset

   ```bash
   ./scripts/download.sh -p 2024/01 2024/12
   ```

   Will download the prices updates dataset for the months from 2024/01 to 2024/12, both extremes included (around 13 GB uncompressed). 

   This repository contains already a prepared version of the gas stations dataset with their prices in `data/`. 

   > If you wanted to work on prices after 21/01/2025 you need to download an up-to-date stations dataset and prepare it ( see `scripts/data_preparation.md`).

2. ### Start the Database

   Assuming you have [CedarDB image locally](https://cedardb.com/docs/getting_started/running_docker_image/) as `cedardb`. Running

   ```bash
   docker compose up -d
   ```

   Starts CedarDB and [Grafana](https://grafana.com/). You access Grafana at http://localhost:3000/ with username `admin` and password `admin`.

   > You can stop the containers with `docker compose down`. By default the database is persisted with a docker volume, if you want a fresh start run `docker compose down -v` to remove the volumes

3. ### Load the data

   ```bash
   ./scripts/load.sh -c -s -p 2024/01 2024/06
   ```

   This will:

   - create the schema `sql/schema.sql` (`-c`)

   - load stations and stations times (opening hours for each stations) from data (`-s`)

   - load all prices in `data/prices` (and subfolders) between 2024/01/01 (included) and 2024/06/01 (not included) (`-p 2024/01 2024/06`).

     >  The loading of the prices can take a while based on the chunk you're loading

4. ### Replay Transactional Workload (`optional`)

   This step is optional, as you can already run queries on the loaded data. In this step we start a python client that replays the remaining part of the dataset as a series of inserts. You can start it with

   ```bash
   docker compose run -it --rm --name replayer replayer -p /data -s 60
   ```

   If for example you've downloaded the entire 2024 and loaded until 2024/06/01 (not included), this will simulate the insertion of all price updates starting from 2024/06/01 with a factor speed of 60 (`-s 100`), executing every second one minute of transactions.

   > If you don't have docker compose take a look [here](scripts/replay/README.md), to see alternative ways of starting replayer 

5. ### Query the data

   To run queries:

   ```bash
   psql 'host=localhost user=client dbname=client password=client'
   ```

   > If you don't have psql locally installed you can always use the one in CedarDB's container with
   >
   > ```bash
   > docker exec -it cedar psql 'user=client dbname=client password=client'
   > ```

   #### Some examples

   To check the prices chunk you've loaded:

   ```sql
   select min(time)as first , max(time) as  last, count(*) as n_events from prices;
   ```





If you want to continue with a more in depth exploration of the dataset you take a look at the [analysis](https://ludof63.github.io/MTSK-analysis/analysis/).

