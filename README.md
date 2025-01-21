# An Analysis of Germany's Fuel Prices

A data analysis of the historical fuel prices in Germany with [CedarDB](https://cedardb.com).

The [Markttransparenzstelle für Kraftstoffe](https://www.bundeskartellamt.de/DE/Aufgaben/MarkttransparenzstelleFuerKraftstoffe/MTS-K_Infotext/mts-k_node.html) (MTS-K) collects the fuel prices for gas station all over Germany. A history of all price changes is available [here](https://dev.azure.com/tankerkoenig/tankerkoenig-data). 

This repository contains:

- A collection of analysis on the fuel prices in Germany
- Scripts to download/prepare/ingest the dataset

You can **take a look at the analysis [here](https://ludof63.github.io/MTSK-analysis/analysis/).** Or you can run some queries on the dataset yourself, following the next steps.

## Getting Started

1. ### Download the Dataset

   ```bash
   ./scripts/download.sh -p
   ```

   Will download the prices changes dataset. By default it downloads entire 2024 (around 13 GB), but you can change that in the script. This repository contains already a prepared version of the gas stations dataset with their prices in `data/`. 

   > If you wanted to work on prices after 21/01/2025 you need to download an up-to-date stations dataset and prepare it ( see `scripts/data_preparation.md`).

2. ### Start the Database

   Assuming you have [CedarDB image locally](https://cedardb.com/docs/getting_started/running_docker_image/) as `cedardb` 

   ```bash
   docker-compose up -d
   ```

   Starts CedarDB and [Grafana](https://grafana.com/). You access Grafana at http://localhost:3000/ with username `admin` and password `admin`.

   > You can stop both with `docker-compose down`. By default the database is persisted with a docker volume, if you want a fresh start run `docker-compose down -v`

3. ### Load the data

   ```bash
   ./scripts/load.sh -c -s -p data/prices
   ```

   This will:

   - create the schema `sql/schema.sql` (`-c`)

   - load stations and stations times (opening hours for each stations) from data (`-s`)

   - load all prices in `data/prices`. (`-p data/prices`)

     > If you want to load less data you can specify a sub-folder, e.g., `./scripts/load.sh -p data/prices/2024/01` would load all prices of January 2024 (dropping and recreating prices table)

4. ### Query the data

   To run queries:

   ```bash
   psql 'host=localhost user=client dbname=client password=client'
   ```

   > If you don't have psql locally installed you can always use the one in CedarDB's container with
   >
   > ```bash
   > docker exec -it cedar psql 'user=client dbname=client password=client'
   > ```

   

   Here are some queries to start:

   ```sql
   select min(time)as first , max(time) as  last, count(*) as n_events from prices;
   ```

​	To check the prices chunk you've loaded



If you want to continue with a more in depth exploration of the dataset you take a look at the [analysis](https://ludof63.github.io/MTSK-analysis/analysis/).

