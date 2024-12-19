# An Analysis of Germany's Fuel Prices

A data analysis of the historical fuel prices in Germany with [CedarDB](https://cedardb.com), a blazingly fast **HTAP** database.

The [Markttransparenzstelle für Kraftstoffe](https://www.bundeskartellamt.de/DE/Aufgaben/MarkttransparenzstelleFuerKraftstoffe/MTS-K_Infotext/mts-k_node.html) (MTS-K) collects the fuel prices of gas stations all over Germany. A history of all price changes is available at https://dev.azure.com/tankerkoenig/tankerkoenig-data. 

This repository contains mainly:

- Scripts to download/prepare/ingest the dataset
- A collection of data analysis examples

## Getting Started with MTS-K analysis

1. **Download the Dataset**
   This repository already contains a prepared version of the gas stations dataset in `data/`  (more details on the preprocessing in `scripts/data_prep/README.md`).  To start the analysis you first need to download a chunk of historical prices. You can do that running the following:

   ```bash
   ./scripts/download.sh data -p
   ```

   This will download in the data_folder (by default `data/`) the prices files. By default it downloads one year of historical data (from 2023/11 to 2024/11), which uncompressed is around 13 GB. To download a different time period, refer to `/scripts/README.md`.

2. **Start the Database**

   Assuming you have CedarDB docker image locally as `cedardb` , you can run

   ```bash
   docker-compose up
   ```

   This will take care of initializing a database, creating the schema `sql/MTS-K_schema.sql` and loading the data. It does so by utilizing a custom docker image that build on top of `cedardb`. 

   CedarDB will run scripts in`/docker-entrypoint-initdb.d/` [during the initialization of the db](https://cedardb.com/docs/getting_started/running_docker_image/#preloading-data). 
   The custom image copies a loading script (`scripts/loadMTS-K.sh`) and then adds a single line script in `/docker-entrypoint-initdb.d/` that runs the loading script.

   For the initialization phase uses the configurations (environment variables passed to the container) in `.env`. These are used by CedarDB in first place to initialize the database (`CEDAR_USER`, `CEDAR_PASSWORD`, `CEDAR_DB`) and then by `scripts/loadMTS-K.sh` to determine which data to load. 

   For example, `PRICES_FOLDER = prices/` means the script will load all the prices file in `/data`, the is mounted as a volume for the container on `./data ` in the `docker-compose.yml`.  

   > If you don't have docker-compose locally you can run it directly with docker but also with podman using the script `./scripts/runCedarDB.sh` (see `/scripts/README.md`)

   > As explained before, by default on database initialization the loading scripts loads all prices `./data/prices/`. This can take a while if you've downloaded 1 year of data.

   > The database is persisted using the volume `cedard_data` (details in `docker-compose.yml)`.

   > `scripts/loadMTS-K.sh` can be used to load data after the initialization (see `/scripts/README.md`)

3. **Query the Database**

   With the default configurations you can access CedarDB running

   ```bash
   docker exec -it cedardb_runner psql ' user=client dbname=client password=client'
   ```


    If you have [psql](https://cedardb.com/docs/clients/psql/) locally, you can run directly

   ```bash
   psql 'host=localhost user=client dbname=client password=client'
   ```


## Analyzing Germany Fuel Prices

Main results...TODO
