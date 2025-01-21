#!/bin/bash
set -e

PATH_TO_SCHEMA="sql/schema.sql"
PATH_TO_STATIONS="/data/stations.csv"
PATH_TO_TIMES="/data/stations_times.csv"

PRICES_TABLE=prices
STATIONS_TABLE=stations
CLUSTERS_TABLE=stations_clusters
TIMES_TABLE=stations_times

CONTAINER=cedar

do_create=0
do_stations=0
do_prices=0
prices_dir=""

usage() {
    echo "Usage: $0 [-c] [-s] [-p <prices_dir>] [-o]"
    echo "  -c              creates schema from $PATH_TO_SCHEMA"
    echo "  -s              loads stations from $PATH_TO_STATIONS and $PATH_TO_TIMES "
    echo "  -p <prices_dir> loads prices from <prices_dir>"
    exit 1
}


if [[ ! -e ".env" ]]; then
    echo "Cannot find .env file"
    exit 1
fi
source .env
CONN_STR="host=localhost user=$CEDAR_USER dbname=$CEDAR_DB password=$CEDAR_PASSWORD"


while getopts ":cp:so" opt; do
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
        o)
            CONTAINER=postgres
            echo "Using use postgres -> container: $CONTAINER"
            ;;
        ?)
            echo "Invalid option"
            usage
            ;;
        *)
            usage
            ;;
    esac
done


#--------------------------------------------------------------------
DOCKER=docker
if [ -n "$USE_PODMAN" ]; then
    DOCKER=podman
    echo "Using Podman as the container runtime."
fi


run_cmd(){
    $DOCKER exec $CONTAINER "$@"
}


execute_query(){
    echo -e "Executing:\n$1"
    run_cmd psql -v ON_ERROR_STOP=1 "$CONN_STR" -c "$1"
    echo -e "\n"
}

file_exists(){
    run_cmd test -e "$1"

    if [ $? -eq 0 ]; then
        return 0
    else
        return 1
    fi
}

extract_table_schema() {
    local table_name=$1

    awk -v table="create table[[:space:]]*$table_name" '
        BEGIN {ignore_case=1}
        tolower($0) ~ table {print; found=1; next}  
        found && /^);$/ {print; exit}                
        found {print}                                
    ' "$PATH_TO_SCHEMA"
}

recreate_table(){
    if [[ "$do_create" -eq 0 ]]; then
        execute_query "drop table if exists $1;"
        execute_query "$(extract_table_schema $1)"
    fi
}


if [[ ! -e "$PATH_TO_SCHEMA" ]]; then
    echo "Cannot continue without $PATH_TO_SCHEMA"
    exit 1
fi


#create schema---------------------------------
if [[ "$do_create" -eq 1 ]]; then
    execute_query "$(cat $PATH_TO_SCHEMA)"
    echo "Schema for MTS-K created"
fi


#stations --------------------------------------
if [[ "$do_stations" -eq 1 ]]; then
    #stations
    if file_exists $PATH_TO_STATIONS; then
        recreate_table $STATIONS_TABLE
        execute_query "copy $STATIONS_TABLE from '$PATH_TO_STATIONS' with(format csv, delimiter ',', null '', header true);"
    else
        echo "File not found $PATH_TO_STATIONS -> doing nothing"
    fi

    #times table
    if file_exists $PATH_TO_TIMES; then
        recreate_table $TIMES_TABLE
        execute_query "copy $TIMES_TABLE from '$PATH_TO_TIMES' with(format csv, delimiter ',', null '', header true);"
    else
        echo "File not found $PATH_TO_TIMES -> doing nothing"
    fi
fi

#prices ----------------------------------------
if [[ "$do_prices" -eq 1 ]]; then
    recreate_table $PRICES_TABLE

    run_cmd find "/$prices_dir" -type f -name "*-prices.csv" | sort | while read -r file; do
        query="copy $PRICES_TABLE from '$file' with(format csv, delimiter ',', null '', header true);"
        execute_query "$query"
    done
fi