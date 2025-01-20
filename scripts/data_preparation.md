# Data Preparation

While we can work directly with the prices dataset with few touches, the stations dataset from MTS-K needs some preprocessing. If you use the stations dataset provided in this repository, you can ignore the stations preprocessing.

## Cleaning Prices Dataset

Once we've loaded the prices, during my experiments I've noticed some weird values and after a bit of investigations I realized there is a very small number (compared to the size of the dataset) of wrong price entries for some stations (the prices are negative). One can remove these prices using the following query (`/sql/cleaning/RemoveNegativePrices.sql`)

```postgresql
DELETE 
FROM prices 
WHERE (diesel_change in (1,3) and diesel < 0) OR (e5_change in (1,3) and e5 < 0) OR (e10_change in (1,3) and e10 < 0);
```

## Preparing Stations Dataset

What do we have to prepare?

1. Parse opening times of each station and prepare each station following the schema `/sql/MTS-K_schema.sql`  (to then use a [`COPY FROM` statement](https://cedardb.com/docs/references/sqlreference/statements/copy/))
2. Ignore invalid stations, fix stations with invalid PLZ, coordinates 
3. With valid PLZ and coordinate, make city attribute uniform (useful for aggregations in the analysis)
4. Make brand attribute uniform

`prepare_stations.py` executes the data preparation and requires only an up-to-date python version installed locally (you can download and install python from  [here](https://www.python.org/downloads/)).

`prepare_stations.py` requires two arguments `<station_file> <region_file>` where `<station_file>` is a path to the stations dataset as download from [here](https://dev.azure.com/tankerkoenig/tankerkoenig-data/_git/tankerkoenig-data?path=/stations) (most up to date is yesterday's file), while `<region_file>` is the path to the official  Germany's PLZ to cities mappings, that you can download from [here](https://downloads.suche-postleitzahl.org/v2/public/zuordnung_plz_ort.csv) (needed for 2 and 3).

> You can download the files manually or use `/scripts/download.sh`

It produces two csv files for `stations` and `stations_times` (following the schema in `sql/MTS-K_schema.sql`). By default it saves both of them in the same directory of `<station_file>` 

Running in the root of the repository

```bash
./scripts/download.sh data -s
```

downloads an up-to-date original stations dataset in `data/stations_original.csv` and plz-dataset in `data/zuordnung_plz_ort.csv`, that we can prepare with

```bash
python scripts/data_prep/clear_stations.py data/stations_original.csv data/zuordnung_plz_ort.csv
```

this saves the results in `data/stations.csv` and `data/stations_times.csv` (overriding the preprepared station dataset that comes with the repository)

### Brief explanation

- To solve 1 and 4 each row before being written to the output file is passed through a "parse function" that additionally parses the time and adds it to a global list of station_times, written in the end to file too.
- To solve 2 and 3 we use the mappings between PLZs and cities we have in `<region_file>` as the source of truth for the stations PLZs. Each station is check for correctness of PLZ and coordinates, if problems are found, we use [OSM](https://nominatim.openstreetmap.org/ui/search.html) to fix them.