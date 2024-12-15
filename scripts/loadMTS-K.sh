#!/bin/bash
set -e

#execute in project root
source .env
PATH_TO_DATA_FOLDER="data"
PATH_TO_SQL_FOLDER="sql"

CONN_STR="host=localhost user=$CEDAR_USER dbname=$CEDAR_DB password=$CEDAR_PASSWORD"

CONTAINER=cedardb_runner
#for flag -o
postgres_container=postgres_runner

do_create=0
do_stations=0
do_prices=0
do_clusters=0
prices_dir=""

usage() {
    echo "Usage: $0 [-c] [-p prices_dir] [-s] [-r] [-o]"
    echo "  -c              create schema ($PATH_TO_SQL_FOLDER/$SCHEMA_FILE)"
    echo "  -p prices_dir   load prices from prices_dir in $PATH_TO_DATA_FOLDER "
    echo "  -s              load stations from $PATH_TO_DATA_FOLDER/$STATION_FILE "
    echo "  -c              load clusters from $PATH_TO_DATA_FOLDER/$CLUSTER_FILE"
    echo "  -o              use postgres -> container: $postgres_container"
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
            CONTAINER=$postgres_container
            echo "Using use postgres -> container: $postgres_container"
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


#utility function to extract create_table statement for a table from schema
extract_create_table() {
    local schema_file=$1
    local table_name=$2

    awk -v table="create table[[:space:]]*$table_name" '
        BEGIN {ignore_case=1}
        tolower($0) ~ table {print; found=1; next}  
        found && /^);$/ {print; exit}                
        found {print}                                
    ' "$schema_file"
}


execute_query(){
    echo -e "Executing:\n$1"
    docker exec $CONTAINER psql -v ON_ERROR_STOP=1 "$CONN_STR" -c "$1"
    echo -e "\n"
}


PATH_TO_SCHEMA="$PATH_TO_SQL_FOLDER/$SCHEMA_FILE"
if [ ! -e "$PATH_TO_SCHEMA" ]; then
    echo "Cannot continue without schema $PATH_TO_SCHEMA"
    exit 1
fi



#create schema---------------------------------
if [[ "$do_create" -eq 1 ]]; then
  execute_query "$(cat "$PATH_TO_SQL_FOLDER/$SCHEMA_FILE")" || exit 1
fi


#prices ----------------------------------------
if [[ "$do_prices" -eq 1 ]]; then
    if [[ "$do_create" -eq 0 ]]; then
        execute_query "drop table if exists $PRICES_TABLE;"
        execute_query "$(extract_create_table "$PATH_TO_SQL_FOLDER/$SCHEMA_FILE" $PRICES_TABLE)"
    fi

    find $prices_dir -type f -name "*-prices.csv" | sort | while read -r file; do
        f="${file#"$PATH_TO_DATA_FOLDER/"}"
        query="copy $PRICES_TABLE from '$DATA_FOLDER/$f' with(format csv, delimiter ',', null '', header true);"
        execute_query "$query"
    done
fi

#stations --------------------------------------
if [[ "$do_stations" -eq 1 ]]; then

    PATH_TO_STATIONS="$DATA_FOLDER/$STATION_FILE"
    if [ -e "$PATH_TO_STATIONS" ]; then
        if [[ "$do_create" -eq 0 ]]; then
            execute_query "drop table if exists $STATIONS_TABLE;"
            execute_query "$(extract_create_table "$PATH_TO_SQL_FOLDER/$SCHEMA_FILE" $STATIONS_TABLE)"
        fi
        execute_query "copy $STATIONS_TABLE from $PATH_TO_STATIONS with(format csv, delimiter ',', null '', header true);"
    else
        echo "File not found $PATH_TO_STATIONS -> doing nothing"
    fi


    PATH_TO_TIMES="$DATA_FOLDER/$TIMES_FILE"
    if [ -e "$PATH_TO_STATIONS" ]; then
        if [[ "$do_create" -eq 0 ]]; then
            execute_query "drop table if exists $TIMES_TABLE;"
            execute_query "$(extract_create_table "$PATH_TO_SQL_FOLDER/$SCHEMA_FILE" $TIMES_TABLE)"
        fi
        execute_query "copy $TIMES_TABLE from $PATH_TO_TIMES with(format csv, delimiter ',', null '', header true);"
    else
        echo "File not found $PATH_TO_TIMES -> doing nothing"
    fi
    

fi


#clusters ----------------------------------------
if [[ "$do_clusters" -eq 1 ]]; then
    PATH_TO_CLUSTERS="$DATA_FOLDER/$CLUSTERS_FILE"
    if [ -e "$PATH_TO_STATIONS" ]; then
        if [[ "$do_create" -eq 0 ]]; then
            execute_query "drop table if exists $CLUSTERS_TABLE;"
            execute_query "$(extract_create_table "$PATH_TO_SQL_FOLDER/$SCHEMA_FILE" $CLUSTERS_TABLE)"
        fi

        execute_query "copy $CLUSTERS_TABLE from $PATH_TO_CLUSTERS with(format csv, delimiter ',', null '', header true);"
    else
        echo "File not found $PATH_TO_CLUSTERS -> doing nothing"
    fi
    
fi