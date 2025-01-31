#!/bin/bash
set -e

PATH_TO_SCHEMA="sql/schema.sql"
PATH_TO_STATIONS="/data/stations.csv"
PATH_TO_TIMES="/data/stations_times.csv"

PRICES_TABLE=prices
STATIONS_TABLE=stations
TIMES_TABLE=stations_times

PRICES_DIR="/data/prices"

CONTAINER=cedar

do_create=0
do_stations=0
do_prices=0

usage() {
    echo "Usage: $0 [-c] [-s] [-p  <year/mm> <year/mm> ] [-o]"
    echo "  -c              creates schema from $PATH_TO_SCHEMA"
    echo "  -s              loads stations from $PATH_TO_STATIONS and $PATH_TO_TIMES "
    echo "  -p <year/mm start> <year/mm end> loads prices from $PRICES_DIR from start to end"
    exit 1
}

validate_year_month() {
    if [[ ! $1 =~ ^[0-9]{4}/(0[1-9]|1[0-2])$ ]]; then
        echo "Error: Invalid date format '$1'. Expected 'year/mm'"
        exit 1
    fi
}


if [[ ! -e ".env" ]]; then
    echo "Cannot find .env file"
    exit 1
fi
source .env
CONN_STR="host=localhost user=$CEDAR_USER dbname=$CEDAR_DB password=$CEDAR_PASSWORD"


while getopts "csp:o" opt; do
    case "$opt" in
        c)
            do_create=1
            ;;
        s)
            do_stations=1
            ;;
        p)
            do_prices=1
            start_date=${OPTARG}
            echo "Start date $start_date"
            shift $((OPTIND -1))
            end_date=$1
            echo "End date $end_date"
            ;;
        o)
            CONTAINER=postgres
            echo "Using use postgres -> container: $CONTAINER"
            ;;
        *)
            usage
            ;;
    esac
done

if [[ $do_prices -eq 1 ]] && [[ -z "$start_date" || -z "$end_date" ]]; then
    echo "Error: -p requires both <year/mm start> and <year/mm end>"
    usage
fi

if [[ $do_prices -eq 1 ]]; then
    validate_year_month $start_date
    validate_year_month $end_date   

    # Ensure start < end
    if [[ $(date -d "$start_date/01" +%s) -gt $(date -d "$end_date/01" +%s) ]]; then
        echo "Error: Start date ($start_date) must be earlier than end date ($end_date)."
        exit 1
    fi
fi


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





#--------------------------------------------------------------------
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
    echo "Loading from $start_date/01 to $end_date/01"

    recreate_table $PRICES_TABLE

    run_cmd find "$PRICES_DIR" -type f -name "*-prices.csv" | sort | while read -r file; do
        file_date=$(basename "$file" | cut -d'-' -f1-3)

        if [[ $(date -d "$file_date" +%s) -ge $(date -d "$start_date/01" +%s) && $(date -d "$file_date" +%s) -lt $(date -d "$end_date/01" +%s) ]]; then
            query="copy $PRICES_TABLE from '$file' with(format csv, delimiter ',', null '', header true);"
            execute_query "$query"
        fi

    done
fi