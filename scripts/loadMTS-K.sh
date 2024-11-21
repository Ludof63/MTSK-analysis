#!/bin/bash
CONTAINER_DIR=/datasets

STATION_FILE="/data/stations_official.csv"         #relative to data_folder (and datasets)
REGION_FILE="/data/germany_regions.csv"    #relative to data_folder (and datasets)


PG_CONN_STR="host=localhost dbname=client user=client password=client"

SCHEMA="sql/MTS-K_schema.sql"
PRICES_TABLE=prices
STATIONS_TABLE=stations
REGION_TABLE=regions

CONTAINER=cedardb_runner
PORT=5432

postgres_container=postgres_runner
postgres_port=54321

do_create=0
do_stations=0
do_prices=0
do_regions=0
prices_dir=""

usage() {
    echo "Usage: $0 [-c] [-p prices_dir] [-s] [-r] [-o]"
    echo "  -c              create schema"
    echo "  -p prices_dir   load prices from prices_dir"
    echo "  -s              load stations from $STATION_FILE "
    echo "  -r              load regions from $REGION_FILE"
    echo "  -o              use postgres -> container: $postgres_container | listening on $postgres_port "
    exit 1
}

get_real_path() {
    local relative_path="$1"
    local script_dir="$(dirname "$(realpath "$0")")"
    echo "$(realpath "$script_dir/$relative_path")"
}


while getopts ":cp:sro" opt; do
    case $opt in
        c)
            do_create=1
            ;;
        s)
            do_stations=1
            ;;
        p)
            do_prices=1
            prices_dir="$OPTARG"
            ;;
        r)
            do_regions=1
            ;;
        o)
            CONTAINER=$postgres_container
            PORT=$postgres_port
            echo "Using use postgres -> container: $postgres_container | listening on $postgres_port"
            ;;
        ?)
            echo "Invalid option $opt"
            usage
            ;;
        *)
            usage
            ;;
    esac
done


EXECUTOR=psql
execute_query(){
  echo -e "Executing:\n$1"
  case $EXECUTOR in
    psql)
        psql "$PG_CONN_STR" -p $PORT -c "$1"
        ;;
    docker)
        docker exec $CONTAINER psql "$PG_CONN_STR" -c "$1"
        ;;
  esac
  echo -e "\n"
}


#create schema---------------------------------
if [[ "$do_create" -eq 1 ]]; then
  execute_query "$(cat $SCHEMA)" || exit 1
fi


#prices ----------------------------------------
if [[ "$do_prices" -eq 1 ]]; then
    if [[ "$do_create" -eq 0 ]]; then
        execute_query "truncate table $PRICES_TABLE;"
    fi

    find $prices_dir -type f -name "*-prices.csv" | sort | while read -r file; do
        query="copy $PRICES_TABLE from '$CONTAINER_DIR/$file' with(format csv, delimiter ',', null '', header true);"
        execute_query "$query"
    done
fi

#stations --------------------------------------
if [[ "$do_stations" -eq 1 ]]; then
    if [[ "$do_create" -eq 0 ]]; then
        execute_query "truncate table $STATIONS_TABLE;"
    fi
    
    execute_query "copy $STATIONS_TABLE from '$CONTAINER_DIR/$STATION_FILE' with(format csv, delimiter ',', null '', header true);"
fi


#regions ----------------------------------------
if [[ "$do_regions" -eq 1 ]]; then
    if [[ "$do_create" -eq 0 ]]; then
        execute_query "truncate table $REGION_TABLE;"
    fi
    
    execute_query "copy $REGION_TABLE from '$CONTAINER_DIR/$REGION_FILE' with(format csv, delimiter ',', null '', header true);"
    
fi