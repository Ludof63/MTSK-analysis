#!/bin/bash
OUTPUT_FOLDER="data"    #where to donwload
REMOVE_ZIP=true         #keep zip files?

#prices to download 
START_DATE_PRICES="2024/01"
END_DATE_PRICES="2024/12" 

#stations to download (1 file)
date_station_file="$(date --date="yesterday" "+%Y-%m-%d")" #latest stations file (custom date with "2024-11-01")
station_file="${date_station_file}-stations.csv" 
station_path="stations/$(date -d "$date_station_file" "+%Y/%m")/${station_file}"



file_station_out="stations_original.csv"
folder_prices_out="prices"


#https://dev.azure.com/tankerkoenig/tankerkoenig-data/_git/tankerkoenig-data
org=tankerkoenig
repo=tankerkoenig-data

#https://www.suche-postleitzahl.org/downloads
base_url="https://downloads.suche-postleitzahl.org/v2/public"
plz_info="zuordnung_plz_ort.csv"
plz_5stellig="plz-5stellig.shp.zip"

# -------------------------------------------------
download_stations=false
download_prices=false
while getopts "sp" opt; do
    case "$opt" in
        s) download_stations=true ;;
        p) download_prices=true ;;
        *) 
            echo "Invalid option: -$OPTARG"
            echo "Usage: $0 [-s] [-p]"
            exit 1
            ;;
    esac
done

set +x
mkdir -p $OUTPUT_FOLDER

if $download_stations; then
    curl -L -o "${OUTPUT_FOLDER}/${file_station_out}" "https://dev.azure.com/${org}/${repo}/_apis/git/repositories/${repo}/items?path=${station_path}"
    curl -L -o "${OUTPUT_FOLDER}/${plz_info}" "${base_url}/${plz_info}"
fi

if $download_prices; then
    prices_folder="${OUTPUT_FOLDER}/${folder_prices_out}"
    mkdir -p $prices_folder

    current_date="$START_DATE_PRICES"
    END_DATE_PRICES_month=$(date -d "$END_DATE_PRICES/01 + 1 month" "+%Y/%m")
    echo $END_DATE_PRICES_month

    while [[ "$current_date" < "$END_DATE_PRICES_month" ]]; do
        filename="prices_$(echo "$current_date" | sed 's/\//_/').zip"
        echo "Downloading prices for $current_date in $filename"

        year_folder="$prices_folder/$(date -d "$current_date/01" "+%Y")"

        prices_url="https://dev.azure.com/${org}/${repo}/_apis/git/repositories/${repo}/items?path=prices/${current_date}&%24format=zip"

        set -x
        mkdir -p $year_folder        
        curl -L -o "${OUTPUT_FOLDER}/${folder_prices_out}/${filename}" $prices_url
        unzip -qo "${OUTPUT_FOLDER}/${folder_prices_out}/${filename}" -d $year_folder
        if $REMOVE_ZIP; then
            rm ${OUTPUT_FOLDER}/${folder_prices_out}/${filename}
        fi
        set +x

        current_date=$(date -d "$current_date/01 + 1 month" +%Y/%m)
    done
fi


