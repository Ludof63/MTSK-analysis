#!/bin/bash

#https://dev.azure.com/tankerkoenig/tankerkoenig-data/_git/tankerkoenig-data
org=tankerkoenig
repo=tankerkoenig-data
data_folder=data

#stations 2024
stations_subfolder="/stations/2024"
station_out="${data_folder}/stations"

#prices 2024-04
prices_subfolder="/prices/2024/04"
prices_out="${data_folder}/prices"


set -x
mkdir -p $data_folder

stations_url="https://dev.azure.com/${org}/${repo}/_apis/git/repositories/${repo}/items?path=${stations_subfolder}&%24format=zip"
curl -L -o ${station_out}.zip $stations_url
unzip -q ${station_out}.zip -d $station_out

prices_url="https://dev.azure.com/${org}/${repo}/_apis/git/repositories/${repo}/items?path=${prices_subfolder}&%24format=zip"
curl -L -o ${prices_out}.zip $prices_url
unzip -q ${prices_out}.zip -d $prices_out