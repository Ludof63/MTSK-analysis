# MTS-K - Analysis with CedarDB

The Markttransparenzstelle für Kraftstoffe (MTS-K) collects all gas station fuel prices all over Germany, the dataset is the collection of all the price changes. 

## Scripts

- Start CedarDB

  ```bash
  ./scripts/runCedarDB.sh
  ```

  Starts CedarDB with docker (image `cedardb`) on port `5432`

- Start Postgres

  ```bash
  ./scripts/runPostgres.sh
  ```

  Starts Postgres with docker (image `postgres`) on port `54321`

- Load MTS-K (all stations  + April price changes)

  ```bash
  ./scripts/loadMTS-K.sh -c -s data/stations -p data/prices/2024/04
  ```

  `-c` creates the MTS-K schema,  `-s` loads the stations, `-p` loads the prices

  `-r` can be specified to use Postgres (instead of CedarDB)

- Start Grafana

  ```bash
  ./scripts/runGrafana.sh
  ```

  Start Grafana in docker, available at http://127.0.0.1:3000
