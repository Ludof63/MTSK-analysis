# An Analysis of Germany's Fuel Prices

A data analysis of the historical fuel prices in Germany with [CedarDB](https://cedardb.com), a blazingly fast **HTAP** database.

The [Markttransparenzstelle für Kraftstoffe](https://www.bundeskartellamt.de/DE/Aufgaben/MarkttransparenzstelleFuerKraftstoffe/MTS-K_Infotext/mts-k_node.html) (MTS-K) collects the fuel prices of gas stations all over Germany. A history of all price changes is available at https://dev.azure.com/tankerkoenig/tankerkoenig-data. 

This repository contains mainly:

- A collection of analysis on the MTS-K dataset
- Scripts to download/prepare/ingest the dataset

**Take a look at the analysis [here](https://ludof63.github.io/MTSK-analysis/analysis/).**

While if you want to run some analysis on the dataset yourself you can follow the next steps.

## Getting Started with MTS-K analysis

1. ### **Download the Dataset**
   
   This repository contains an already prepared stations dataset `data/`  (more details on the preprocessing in `scripts/data_preparation.md`).  To start the analysis you first need to download a chunk of historical prices. You can do that running the following:
   
   ```bash
   ./scripts/download.sh data -p
   ```
   
   This will download in the data_folder (by default `data/`) the prices files. By default it downloads one year of historical data (from 2023/11 to 2024/11), which uncompressed is around 13 GB. To download a different time period take a look at `/scripts/README.md`.
   
2. ### **Start the Database**

   Assuming you have CedarDB image locally as `cedardb` , you can run

   ```bash
   docker-compose up
   ```

   This process initializes the database, creates the schema, and loads data from `sql/MTS-K_schema.sql`. It uses a custom Docker image built on top of `CedarDB`.

   #### How it works

   1. **Base Image Behavior**: CedarDB automatically runs scripts placed in `/docker-entrypoint-initdb.d/` during the database initialization phase. [Read more here](https://cedardb.com/docs/getting_started/running_docker_image/#preloading-data). 
   2. **Custom Image Setup**: A custom loading script (`scripts/loadMTS-K.sh`) is included in the image.  A helper script is added to `/docker-entrypoint-initdb.d/` to trigger the loading script during initialization. 
   3. **Environment Configuration**: The initialization phase relies on environment variables defined in the `.env` file (`CEDAR_USER`, `CEDAR_PASSWORD`, `CEDAR_DB`) used by CedarDB to set up the database.     Additional variables, such as `PRICES_FOLDER`, are used by `scripts/loadMTS-K.sh` to specify the data to load.
   4. **Data Volume**: The data directory is mounted as a Docker volume. For example, `PRICES_FOLDER=prices/` means that all price files in the `./data` directory (mapped to `/data` in the container) will be loaded.

   > If you don't have docker-compose locally you can run it directly with docker (or podman) using the script `./scripts/runCedarDB.sh` (see `/scripts/README.md`)

   > As explained before, by default on database initialization the loading scripts loads all prices `./data/prices/`. This can take a while if you've downloaded 1 year of data.

   > The database is persisted using the volume `cedard_data` (details in `docker-compose.yml)`.

   > `scripts/loadMTS-K.sh` can be used to load data after the initialization (see `/scripts/README.md`)

3. ### **Query the Database**

   With the default configurations you can access CedarDB running

   ```bash
   docker exec -it cedardb_runner psql ' user=client dbname=client password=client'
   ```
   
   If you have [psql](https://cedardb.com/docs/clients/psql/) installed locally, you can run
   
   ```bash
   psql 'host=localhost user=client dbname=client password=client'
   ```
