#!/bin/bash
set -e

OUTPUT_FOLDER="data"    #where to donwload
REMOVE_ZIP=true         #keep zip files?


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
download_stations=0
download_prices=0
while getopts "sp:" opt; do
    case "$opt" in
        s) 
            download_stations=1 
            ;;
        p)
            download_prices=1
            start_date=${OPTARG}
            shift $((OPTIND -1))
            end_date=$1
            ;;
            
        *) 
            echo "Invalid option: -$OPTARG"
            echo "Usage: $0 [-s] [-p  <year/mm> <year/mm> ] "
            exit 1
            ;;
    esac
done

validate_year_month() {
    if [[ ! $1 =~ ^[0-9]{4}/(0[1-9]|1[0-2])$ ]]; then
        echo "Error: Invalid date format '$1'. Expected 'year/mm'"
        echo "Usage: $0 [-s] [-p  <year/mm> <year/mm> ] "
        exit 1
    fi
}

if [[ $download_prices -eq 1 ]] && [[ -z "$start_date" || -z "$end_date" ]]; then
    echo "Error: -p requires both <year/mm start> and <year/mm end>."
    exit 1
fi

if [[ $download_prices -eq 1 ]]; then
    validate_year_month $start_date
    validate_year_month $end_date  

    if [[ $(date -d "$start_date/01" +%s) -gt $(date -d "$end_date/01" +%s) ]]; then
        echo "Error: Start date ($start_date) must be earlier than end date ($end_date)."
        exit 1
    fi 
fi




set +x
mkdir -p $OUTPUT_FOLDER

if [[ $download_stations -eq 1 ]]; then
    echo "Downloading Stations Dataset -> $station_file"
    curl -L -o "${OUTPUT_FOLDER}/${file_station_out}" "https://dev.azure.com/${org}/${repo}/_apis/git/repositories/${repo}/items?path=${station_path}"
    curl -L -o "${OUTPUT_FOLDER}/${plz_info}" "${base_url}/${plz_info}"
fi

if [[ $download_prices -eq 1 ]]; then
    prices_folder="${OUTPUT_FOLDER}/${folder_prices_out}"
    mkdir -p $prices_folder

    current_date="$start_date"
    while [[ $(date -d "$current_date/01" +%s) -le $(date -d "$end_date/01" +%s) ]]; do
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


