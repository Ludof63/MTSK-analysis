# MTS-K - Analysis with CedarDB

The Markttransparenzstelle für Kraftstoffe (MTS-K) collects all gas station fuel prices all over Germany, the dataset is the collection of all the price changes (https://dev.azure.com/tankerkoenig/tankerkoenig-data).  Additionally we use the https://www.suche-postleitzahl.org/downloads to "fix" the stations dataset and to get map information.

## Getting Started with MTS-K analysis

1. Download datasets (everything)

  ```bash
  ./scripts/download.sh data -s -r -p
  ```

  `./scripts/download.sh <data_folder> [-s] [-p] [-r]` automatize the download of different datasets. 

  - It saves the downloaded files in `data_folder`
  - `-s` to download the latest [stations](https://dev.azure.com/tankerkoenig/tankerkoenig-data/_git/tankerkoenig-data?path=/stations)  data
  - `-r`  to download latest  [Germany regions](https://www.suche-postleitzahl.org/downloads)
  - `-p` to download the [prices](https://dev.azure.com/tankerkoenig/tankerkoenig-data/_git/tankerkoenig-data?path=/prices) (default from 2024/04  to 2024/06) 

2. Prepare dataset

  ```bash
  python scripts/prepare_dataset.py data/stations.csv data/zuordnung_plz_ort.csv
  ```

  Stations and regions data have to be prepared (to execute COPY FROM directly in their respective tables). The above command is an invocation of `scripts/prepare_dataset.py <station_file> <region_file> [-c (--clean)]` with the default file names in the folder `data`. 

  > The flag `-c` can be specified to "fix" the stations dataset. In the original stations dataset `post_code` informations are not reliable, the script attempts to fix them by querying [OpenStreeMap](https://nominatim.openstreetmap.org/ui/search.html) for "wrong" stations coordinates.

3. Start CedarDB with preloaded dataset

  ```bash
  docker-compose up --build -d
  ```

  Starts CedarDB using a custom CedarDB docker image that preloads the dataset (downloaded and prepared). The configuration of the container can be found in `.env`

  The initialization of the db is done via the script `scripts/load.sh` that in custom image is copied in `/docker-entrypoint-initdb.d/`

  > The docker-compose configuration makes the database persistent, if you want a clean restart, run `./script/clean_restart.sh`

4. Connect to CedarDB and run queries

  You can connect to CedarDB and run queries as you would do with Postgres. Using the default configuration in `.env` :

  - Using psql

    ```bash
    psql 'host=localhost user=client dbname=client password=client'
    ```

  - Using docker

    ```bash
    docker exec -it cedardb_runner psql ' user=client dbname=client password=client'
    ```

5. Stop CedarDB

  ```bash
  docker-compose down
  ```


## Additional utilities

- Custom Dataset Loading

- Run Postgres

- Run Grafana 

  ```bash
  ./scripts/runGrafana.sh
  ```

  Start Grafana in docker, available at http://127.0.0.1:3000
