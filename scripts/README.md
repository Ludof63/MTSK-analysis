

## Download the Dataset

```bash
./scripts/download.sh <data_folder> [-s] [-p] 
```

This script downloads in data_folder datasets. In particular:

- `-p` : if this option is passed it downloads the prices from [here](https://dev.azure.com/tankerkoenig/tankerkoenig-data/_git/tankerkoenig-data?path=/prices). By default it downloads and extracts 1 year of data, from 2023/11 to 2024/11. The chunk of prices to download can be customized by setting `START_DATE_PRICES` and `END_DATE_PRICES` directly in the script
- `-s`: download the latest original stations dataset from [here](https://dev.azure.com/tankerkoenig/tankerkoenig-data/_git/tankerkoenig-data?path=/stations). It also downloads the official mapping of cities and postcodes in Germany from here. 
  The repository comes with an already prepared station dataset, generated from the stations dataset of 01/12/2024. However, if you want to run the analysis on prices after the 01/12/2024 you should either check that no new station was added or download the original stations dataset with `./scripts/download.sh -s` and then execute the pre-processing as described in `scripts/data_prep/README.md`

## Loading the Dataset

```bash
./scripts/loadMTS-K.sh [-c] [-s] [-p prices_dir] [-r] [-o]
```

This script is used during the initialization of the database to possibly load data but it can also be used locally. The script uses environment variable declared in `.env`. If you want to run it locally, run it in the root of the project. 

> The script uses the existence of `.env` to determine whether is running inside the container or not.

The script also assumes that you're running the database in docker/podman with this repository's default configuration. In particular `-p 5432:5432 -v ./data:$DATA_FOLDER -v ./sql:$SQL_FOLDER`, where `DATA_FOLDER` and `SQL_FOLDER` are also defined in `.env`. 

The most "important" option is:

- `[-p prices_dir]`: this allows you to load prices from a specific folder (in `$DATA_FOLDER` for the container that translates in `data`) For example if you have more years in `data/prices`, you can decide to load just 2023 prices with `./scripts/loadMTS-K.sh -p prices/2023`

  > Watch out it recreates the prices table

If you are doing the preprocessing then `-s` and `-r` can be useful:

- `-s`: recreates `stations` and `station_times` tables and loads them respectively from `data/stations.csv` and `data/stations_times.csv `(file obtained from preprocessing, see `scripts/data_prep/README.md`)

- `-r`: recreates the `stations_clusters`table and loads it from `/data/stations_clusters.csv` (file obtained from preprocessing, see `scripts/data_prep/README.md`) 

Additionally:

-  `-c`: recreates the schema using `sql/MTS-K_schema.sql` 
- `-o`: allows to execute any operation against a postgres container started with `/scripts/runPostgres.sh` (or with the same configurations)

> During its initialization CedarDB runs `/scripts/loadMTS-K.sh -c -s -p $PRICES_FOLDER -r` (see `Dockerfile`), creating schema and trying to load everything. 
>
> As `.env` is passed to the container, all the necessary environment variable are available.

## Run-Scripts

This repository also comes with script to facilitate running containers:

- `/script/runCedarDB.sh` replicates the `docker-compose.yml` configuration with docker commands (if you don't have docker-compose locally.

  > It also runs `set debug.verbosity='debug1';` for more logs from CedarDB

- `/script/runGrafana.sh` starts  [Grafana](https://cedardb.com/docs/clients/grafana/), available at http://127.0.0.1:3000

- `/script/runPostgres.sh` starts a Postgres instance on port `54321` using the same configurations used for CedarDB 