#!/bin/bash
CONTAINER_DIR=/datasets

PG_CONN_STR="host=localhost dbname=client user=client password=client"

SCHEMA="sql/schema/fuel_schema.sql"
PRICES_TABLE=prices
STATIONS_TABLE=stations





do_create=false
do_stations=false
do_prices=false
prices_dir=""
stations_dir=""

# Function to display usage
usage() {
    echo "Usage: $0 <postgres|cedardb> [-c] [-p prices_dir] [-s stations_dir]"
    echo "  -c                create schema"
    echo "  -s stations_dir   load stations from stations_dir"
    echo "  -p prices_dir     load prices from prices_dir"
    exit 1
}

if [[ -z "$1" || ( "$1" != "postgres" && "$1" != "cedardb" ) ]]; then
    echo "Error: First argument must be either 'postgres' or 'cedardb'"
    usage
fi

# Store the first argument and shift it, so getopts can process the remaining options
container="db_$1"
shift

# Parse command line options
while getopts ":cp:s:" opt; do
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
        *)
            usage
            ;;
    esac
done



EXECUTOR=docker
execute_query(){
  echo -e "Executing:\n$1"
  case $EXECUTOR in
    psql)
        psql "$PG_CONN_STR" -c "$1"
        ;;
    docker)
        docker exec $container psql "$PG_CONN_STR" -c "$1"
        ;;
    python)
        echo $1 | python client/runner.py
        ;;
  esac
  echo -e "\n"
}


#create schema---------------------------------
if $do_create; then
  execute_query "$(cat $SCHEMA)"
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
  query="copy $STATIONS_TABLE from '$CONTAINER_DIR/$summary_file' with(format csv, delimiter ',', null '', header true);"
  execute_query "$query"
fi


#prices ----------------------------------------
if $do_prices; then
  find $prices_dir -type f -name "*-prices.csv" | sort | while read -r file; do
      query="copy $PRICES_TABLE from '$CONTAINER_DIR/$file' with(format csv, delimiter ',', null '', header true);"
      execute_query "$query"
  done
fi