#!/bin/bash
set -e

#execute in project root (when running outside container)
IS_RUNNING_IN_CONTAINER=1
if [ -e ".env" ]; then
    echo "Loading ENV variable from .env"
    source .env
    IS_RUNNING_IN_CONTAINER=0
fi


if [ $IS_RUNNING_IN_CONTAINER -eq 0 ];then
    CONN_STR="host=localhost user=$CEDAR_USER dbname=$CEDAR_DB password=$CEDAR_PASSWORD"
else
    CONN_STR="user=$CEDAR_USER dbname=$CEDAR_DB"
fi

PATH_TO_SCHEMA="$SQL_FOLDER/$SCHEMA_FILE"
PATH_TO_STATIONS="$DATA_FOLDER/$STATIONS_FILE"
PATH_TO_TIMES="$DATA_FOLDER/$TIMES_FILE"
PATH_TO_CLUSTERS="$DATA_FOLDER/$CLUSTERS_FILE"

CONTAINER=cedardb_runner
PG_CONTAINER=postgres_runner #for flag -o 

do_create=0
do_stations=0
do_prices=0
do_clusters=0
prices_dir=""

usage() {
    echo "Usage: $0 [-c] [-s] [-p prices_dir] [-r] [-o]"
    echo "  -c              create schema from $PATH_TO_SCHEMA (container-relative)"
    echo "  -s              load stations from $DATA_FOLDER/$STATION_FILE (container-relative) "
    echo "  -p prices_dir   load prices from <prices_dir> in $DATA_FOLDER (container-relative)"
    echo "  -r              load clusters from $DATA_FOLDER/$CLUSTER_FILE (container-relative)"
    echo "  -o              use postgres -> container: $PG_CONTAINER"
    exit 1
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
            do_clusters=1
            ;;
        o)
            CONTAINER=$PG_CONTAINER
            echo "Using use postgres -> container: $PG_CONTAINER"
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


#--------------------------------------------------------------------
DOCKER=docker
if [ -n "$USE_PODMAN" ]; then
    DOCKER=podman
    echo "Using Podman as the container runtime."
fi


run_cmd(){
    if [ $IS_RUNNING_IN_CONTAINER -eq 0 ];then
        $DOCKER exec $CONTAINER "$@"
    else
        "$@"
    fi
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

if ! file_exists $PATH_TO_SCHEMA; then
    echo "Cannot continue without schema $PATH_TO_SCHEMA"
    exit 0
fi

extract_table_schema() {
    local table_name=$1

    run_cmd awk -v table="create table[[:space:]]*$table_name" '
        BEGIN {ignore_case=1}
        tolower($0) ~ table {print; found=1; next}  
        found && /^);$/ {print; exit}                
        found {print}                                
    ' "$PATH_TO_SCHEMA"
}

reset_table_if_not_create(){
    local table_name=$1

    if [[ "$do_create" -eq 0 ]]; then
        execute_query "drop table if exists $table_name;"
        execute_query "$(extract_table_schema $table_name)"
    fi
}


#create schema---------------------------------
if [[ "$do_create" -eq 1 ]]; then
    run_cmd psql -v ON_ERROR_STOP=1 "$CONN_STR" -f $PATH_TO_SCHEMA
    echo "Schema for MTS-K created"
fi


#stations --------------------------------------
if [[ "$do_stations" -eq 1 ]]; then
    #stations
    if file_exists $PATH_TO_STATIONS; then
        reset_table_if_not_create $STATIONS_TABLE
        execute_query "copy $STATIONS_TABLE from '$PATH_TO_STATIONS' with(format csv, delimiter ',', null '', header true);"
    else
        echo "File not found $PATH_TO_STATIONS -> doing nothing"
    fi

    #times table
    if file_exists $PATH_TO_TIMES; then
        reset_table_if_not_create $TIMES_TABLE
        execute_query "copy $TIMES_TABLE from '$PATH_TO_TIMES' with(format csv, delimiter ',', null '', header true);"
    else
        echo "File not found $PATH_TO_TIMES -> doing nothing"
    fi
fi

#prices ----------------------------------------
if [[ "$do_prices" -eq 1 ]]; then
    reset_table_if_not_create $PRICES_TABLE

    run_cmd find "$DATA_FOLDER/$prices_dir" -type f -name "*-prices.csv" | sort | while read -r file; do
        query="copy $PRICES_TABLE from '$file' with(format csv, delimiter ',', null '', header true);"
        execute_query "$query"
    done
fi


#clusters ----------------------------------------
if [[ "$do_clusters" -eq 1 ]]; then
    
    if file_exists $PATH_TO_CLUSTERS; then
        reset_table_if_not_create $CLUSTERS_TABLE

        execute_query "copy $CLUSTERS_TABLE from '$PATH_TO_CLUSTERS' with(format csv, delimiter ',', null '', header true);"
    else
        echo "File not found $PATH_TO_CLUSTERS -> doing nothing"
    fi
    
fi