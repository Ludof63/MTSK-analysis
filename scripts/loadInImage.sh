#!/bin/bash
set -e

#script to initialize container (as /docker-entrypoint-initdb.d/)

execute_query(){
    echo -e "Executing:\n$1"
    psql -v ON_ERROR_STOP=1 --username "$CEDAR_USER" --dbname "$CEDAR_DB" -c "$1"
    echo -e "\n"
}


execute_query "$(cat "$SQL_FOLDER/$SCHEMA_FILE")"
execute_query "copy $STATIONS_TABLE from '$DATA_FOLDER/$STATION_FILE' with(format csv, delimiter ',', null '', header true);"
execute_query "copy $REGION_TABLE from '$DATA_FOLDER/$REGION_FILE' with(format csv, delimiter ',', null '', header true);"

#prices folder from the configuration
find "$DATA_FOLDER/$PRICES_FOLDER" -type f -name "*-prices.csv" | sort | while read -r file; do
    query="copy $PRICES_TABLE from '$file' with(format csv, delimiter ',', null '', header true);"
    execute_query "$query"
done
