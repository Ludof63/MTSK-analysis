#!/bin/bash
set -e

#script to initialize container (as /docker-entrypoint-initdb.d/)

execute_query(){
    echo -e "Executing:\n$1"
    psql -v ON_ERROR_STOP=1 --username "$CEDAR_USER" --dbname "$CEDAR_DB" -c "$1"
    echo -e "\n"
}


PATH_TO_SCHEMA="$SQL_FOLDER/$SCHEMA_FILE"
if [ ! -e $PATH_TO_SCHEMA ]; then
    echo "Cannot continue without schema $PATH_TO_SCHEMA"
    exit 1
fi

execute_query "$(cat "$PATH_TO_SCHEMA")"  #create schema

#STATIONS
PATH_TO_STATIONS="$DATA_FOLDER/$STATION_FILE"
if [ -e $PATH_TO_STATIONS ]; then
    execute_query "copy $STATIONS_TABLE from '$DATA_FOLDER/$STATION_FILE' with(format csv, delimiter ',', null '', header true);"

else
    echo "File not found $PATH_TO_STATIONS -> doing nothing"
fi

#STATIONS TIMES
PATH_TO_TIMES="$DATA_FOLDER/$TIMES_FILE"
if [ -e $PATH_TO_TIMES ]; then
   execute_query "copy $TIMES_TABLE from '$PATH_TO_TIMES' with(format csv, delimiter ',', null '', header true);"
else
    echo "File not found $PATH_TO_TIMES -> doing nothing"
fi


#PRICES
find "$DATA_FOLDER/$PRICES_FOLDER" -type f -name "*-prices.csv" | sort | while read -r file; do
    query="copy $PRICES_TABLE from '$file' with(format csv, delimiter ',', null '', header true);"
    execute_query "$query"
done

#CLUSTERS
PATH_TO_CLUSTERS="$DATA_FOLDER/$CLUSTERS_FILE"
if [ -e $PATH_TO_CLUSTERS ]; then
   execute_query "copy $CLUSTERS_TABLE from '$PATH_TO_CLUSTERS' with(format csv, delimiter ',', null '', header true);"
else
    echo "File not found $PATH_TO_CLUSTERS -> doing nothing"
fi
