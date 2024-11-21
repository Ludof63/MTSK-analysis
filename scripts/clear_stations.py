import csv
import os
from typing import Any, TypeAlias
import Levenshtein
import requests
import random
import pandas as pd

DATA_FOLDER="../data/"
PLZ_REGION_FILE=os.path.join(DATA_FOLDER,"zuordnung_plz_ort.csv")
STELLIG_FILE= os.path.join(DATA_FOLDER,"plz-5stellig.shp")
STATION_INPUT= os.path.join(DATA_FOLDER,"stations.csv")

STATION_OUTPUT=os.path.join(DATA_FOLDER,"stations_official.csv")
REGIONS_OUTPUT=os.path.join(DATA_FOLDER,"germany_regions.csv")

def get_real_path(relative_path : str) -> str:
    script_dir = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(script_dir, relative_path)


def query_location(lat: float, lon:float) -> tuple[str,str] | None:
    url = "https://nominatim.openstreetmap.org/reverse"

    params = {
        'lat': lat,
        'lon': lon,
        "country": "Germany",
        "format": "json",
        "addressdetails": 1
    }
    
    userAgents = ["pippo", "pluto", "paperino"]
    user = random.choice(userAgents)

    try:
        response = requests.get(url, params=params, headers={"User-Agent": user})
        print(f"Sending: {response.url}")
        response.raise_for_status()
        data = response.json()
        if 'address' in data:
            if 'town' in data['address']:
                return data['address']['postcode'],data['address']['town']

            if 'village' in data['address']:
                return data['address']['postcode'],data['address']['village']
            
            if 'city' in data['address']:
                return data['address']['postcode'],data['address']['city']

        return None
        
    except requests.RequestException as e:
        print(f"Error querying the Nominatim API: {e}")
        return None


                
AVOID_STR= ["please delete - bitte loeschen", "Nicht", "mehr aktiv", "", "gelöscht", "Hh Admi-Testkasse", "12345"]

RowType : TypeAlias =  dict[str | Any, str | Any]

columns_to_keep = ['uuid', 'name', 'brand', 'street', 'house_number', 'post_code', 'city', 'latitude', 'longitude']
def filter_row(row : RowType) -> RowType:
    return {key : row.get(key, '') for key in columns_to_keep}

def to_str(row : RowType) -> str:
    columns_to_print = columns_to_keep = ['post_code', 'city']
    s =", ".join([f"{key} : {row.get(key,'')}" for key in columns_to_print])
    s += f", coords: ({row['latitude']},{row['longitude']})"
    return s



def find_best_match(city : str, possible_cities : list[str]) -> tuple[str, float]:
    def normalize_split(city_str : str):
        s = set(city_str.title().replace("-", " ").replace("/", " ").replace("ß", "ss").replace("ö", "oe").replace("ä", "ae").replace("ü","ue").split())
        return {word for word in s if len(word) >= 4}
    
    targets = normalize_split(city)
    for possible_city in possible_cities:
        possible_substrings = normalize_split(possible_city)

        if targets & possible_substrings:
            return possible_city,0
        
    closest_c = min(possible_cities, key=lambda k: Levenshtein.distance(city.title(), k))
    return closest_c, Levenshtein.distance(city.title(),closest_c)


def clear_stations(plz_region_file : str, stations_dataset :str, output :str):
    
    #use official dataset
    plz_to_cities : dict[str, list[str]] = {}
    with open(plz_region_file, 'r') as input_plz_to_city:
            reader_plz_city = csv.DictReader(input_plz_to_city)  

            print(reader_plz_city.fieldnames)
            for row in reader_plz_city:
                plz = row['plz']
                city = row['ort']

                if plz in plz_to_cities:
                    if city not in plz_to_cities[plz]:
                        plz_to_cities[plz].append(city)
                else:
                    plz_to_cities[plz] = [city]

    #os.path.join(input_folder,zuordnung_file)

    with open(output,'w+') as outfile:
        writer = csv.DictWriter(outfile, fieldnames=columns_to_keep)
        writer.writeheader()

        invalid_plz_unknown_city : list[RowType] = [] 
    
        with open(stations_dataset, mode='r', newline='') as infile:
            reader = csv.DictReader(infile) 
            for row in reader:
                plz = row['post_code']
                city = row['city']

                if plz in AVOID_STR or city in AVOID_STR:
                    continue

                if len(plz) < 5:
                    plz = "0"*(5-len(plz)) + plz

                if plz in plz_to_cities: #valid post_code
                    if len(plz_to_cities[plz]) == 1: 
                        row['city'] = plz_to_cities[plz][0] #only once city with that postcode
                    else:
                        #try to find a city name (but not important -> cannot be used in aggregations)
                        match,dst = find_best_match(city,plz_to_cities[plz])
                        if dst <= 0.2:
                            row['city'] = match

                    writer.writerow(filter_row(row))

                else:
                    invalid_plz_unknown_city.append(filter_row(row))
                

        not_good : list[RowType] =[]
        print(f"\ntrying to correct cities with invalid plz: {len(invalid_plz_unknown_city)}")
        for s in invalid_plz_unknown_city:
            print(f"\n{to_str(s)}")
            match = query_location(float(s['latitude']),float(s['longitude']))
            if match:
                print(f"FOUND: {match[0]}, {match[1]} for {s['post_code']}, {s['city']}")
                s['post_code'] = match[0]
                s['city'] = match[1]
                writer.writerow(filter_row(row))
            else:
                print(f"NOT FOUND: for {s['post_code']}, {s['city']}")
                not_good.append(s)
    
        print(f"\nSTILL PROBLEMS: {len(not_good)}")
        for s in not_good:
            print(to_str(s)) 
    

def generate_region(plz_region_file : str, output_file : str):

    new_mapping: dict[str,str] = {'post_code' : 'plz', 'cities' : 'ort', 'landkreis' : 'landkreis', 'bundesland' : 'bundesland' }
    with open(plz_region_file, 'r') as input, open(output_file,'w+') as outfile:
        reader = csv.DictReader(input)  

        writer = csv.DictWriter(outfile, fieldnames=list(new_mapping.keys()))
        writer.writeheader()

        for row in reader:
            writer.writerow({new_key : row.get(old_key, '') for new_key,old_key in new_mapping.items()})



clear_stations(get_real_path(PLZ_REGION_FILE),get_real_path(STATION_INPUT),get_real_path(STATION_OUTPUT))
generate_region(get_real_path(PLZ_REGION_FILE),get_real_path(REGIONS_OUTPUT))