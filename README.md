# MTS-K - Analysis with CedarDB

The Markttransparenzstelle für Kraftstoffe (MTS-K) collects all gas station fuel prices all over Germany, the dataset is the collection of all the price changes (https://dev.azure.com/tankerkoenig/tankerkoenig-data). 

This repository contains a collection of data analysis example with [CedarDB](https://cedardb.com), a postgres-compliant **HTAP** database.

## Getting Started with MTS-K analysis

1. **Download the Dataset**
   This repository already contains in `data/`  the stations dataset (prepared, for more details refer to `scripts/data_prep/README.md`).  The prices dataset (the larger part) can be downloaded using `scripts/download.sh`.

   ```bash
   ./scripts/download.sh data -p
   ```

   `./scripts/download.sh <data_folder> [-s] [-p]` will download in the data_folder (in the example data/) the prices files. By default it downloads one year of historical data from 2023/11 to 2024/11, which uncompressed is around 13 GB. If you want to download a different time period refer to `/scripts/README.md`.

2. **Start Database**

   You can start CedarDB either with

   ```bash
   docker-compose up --build -d
   ```

   or with

   ```bash
   ./scripts/runCedarDB.sh
   ```

   Both solutions use a custom docker image that adds loading script in `/docker-entrypoint-initdb.d/` of the container. This script will be executed the first time the [container is started](https://cedardb.com/docs/getting_started/running_docker_image/#preloading-data) (as the default configuration make the database persistent using the volume `cedardb_data`), and it will create the schema (`sql/MTS-K_schema.sql`) and load the data using the `scripts/loadMTS-K.sh` and the configurations in `.env` .

   > By default `.env` loads all the prices in `data/prices/`. This can take a while, you can follow the status of the initialization using `docker logs -f cedardb_runner` (default behavior of `./scripts/runCedarDB.sh`)

   > Using `./scripts/runCedarDB.sh` you can also use podman

   > You can also start postgres with `./scripts/runPostgres.sh`, this will also setup user and db following `.env`, however you will have to create the schema and load data after. You can do that using `scripts/loadMTS-K.sh` (more details in `/scripts/README.md`) 

3. **Query the Database**

   If you have [psql](https://cedardb.com/docs/clients/psql/) installed in your local environment you can connect using

   ```bash
   psql 'host=localhost user=client dbname=client password=client'
   ```

   otherwise you can use the container's psql with 

   ```bash
   docker exec -it cedardb_runner psql ' user=client dbname=client password=client'
   ```

   > Assuming you're using the default configuration of `.env`

4. **Take a look at the Analysis**

   TODO

   > ```bash
   > ./scripts/runGrafana.sh
   > ```
   >
   > This will start a container with [Grafana](https://cedardb.com/docs/clients/grafana/), available at http://127.0.0.1:3000
