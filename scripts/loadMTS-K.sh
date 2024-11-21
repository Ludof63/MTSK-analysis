#!/bin/bash
CONTAINER_DIR=/datasets
DATA_FOLDER="../data"

PG_CONN_STR="host=localhost dbname=client user=client password=client"

SCHEMA="sql/MTS-K_schema.sql"
PRICES_TABLE=prices
STATIONS_TABLE=stations
REGION_TABLE=regions

CONTAINER=cedardb_runner
PORT=5432

postgres_container=postgres_runner
postgres_port=54321

do_create=false
do_stations=false
do_prices=false
do_regions=false
prices_dir=""
stations_dir=""
region_file=""

usage() {
    echo "Usage: $0 [-c] [-p prices_dir] [-s stations_dir] [-r plz_file] [-o]"
    echo "  -c                create schema"
    echo "  -s stations_dir   load stations from stations_dir"
    echo "  -p prices_dir     load prices from prices_dir"
    echo "  -r region_file    load regions from region_file"
    echo "  -o               use postgres -> container: $postgres_container | listening on $postgres_port "
    exit 1
}


data_folder="../data"

get_real_path() {
    local relative_path="$1"
    local script_dir="$(dirname "$(realpath "$0")")"
    echo "$(realpath "$script_dir/$relative_path")"
}

echo $(get_real_path $data_folder)

exit


while getopts ":cp:s:r:o" opt; do
    case $opt in
        c)
            do_create=true
            ;;
        s)
            do_stations=true
            stations_dir="$OPTARG"
            ;;
        p)
            do_prices=true
            prices_dir="$OPTARG"
            ;;
        r)
            do_regions=true
            region_file="$OPTARG"
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
if $do_create; then
  execute_query "$(cat $SCHEMA)" || exit 1
fi

#stations --------------------------------------
if $do_stations; then
  #1)create a summary of all stations 
  summary_tmp="$stations_dir/summary.csv"
  > $summary_tmp && lines=0
  echo "preparing station summary in $summary_tmp"
  find $stations_dir -type f -name "*-stations.csv" | sort | while read -r file; do
      file_lines=$(wc -l < $file)
      to_copy=$((file_lines - lines))
      lines=$((lines + to_copy))

      tail -n $to_copy $file >> $summary_tmp  
  done


  #2)trim columns
  summary_file="$stations_dir/summary_cut.csv"
  python scripts/trimmer.py $summary_tmp $summary_file
  echo "station summary ready and trimmed in $summary_file"

  #3)load 
  #query="copy $STATIONS_TABLE from '$CONTAINER_DIR/$summary_file' with(format csv, delimiter ',', null '', header true);"
  #execute_query "$query"
fi


#prices ----------------------------------------
if $do_prices; then
    if [ ! $do_create ]; then
        execute_query "drop table if exists $REGION_TABLE;"
    fi

    find $prices_dir -type f -name "*-prices.csv" | sort | while read -r file; do
        query="copy $PRICES_TABLE from '$CONTAINER_DIR/$file' with(format csv, delimiter ',', null '', header true);"
        execute_query "$query"
    done
fi


#prices ----------------------------------------
if $do_regions; then
    if [ ! $do_create ]; then
        execute_query "drop table if exists $REGION_TABLE;"
    fi
    
    query="copy $REGION_TABLE from '$CONTAINER_DIR/$region_file' with(format csv, delimiter ',', null '', header true);"
    execute_query "$query"
fi