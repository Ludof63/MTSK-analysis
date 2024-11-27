import csv
import os
from typing import Any, TypeAlias
import requests
import random
import argparse


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


                


RowType : TypeAlias =  dict[str | Any, str | Any]

columns_to_keep = ['uuid', 'name', 'brand', 'street', 'house_number', 'post_code', 'city', 'latitude', 'longitude']
def filter_row(row : RowType) -> RowType:
    return {key : row.get(key, '') for key in columns_to_keep}

def to_str(row : RowType) -> str:
    columns_to_print = columns_to_keep = ['post_code', 'city']
    s =", ".join([f"{key} : {row.get(key,'')}" for key in columns_to_print])
    s += f", coords: ({row['latitude']},{row['longitude']})"
    return s



def find_best_match(city : str, possible_cities : list[str]) -> str | None:
    def normalize_split(city_str : str):
        s = set(city_str.title().replace("-", " ").replace("/", " ").replace("ß", "ss").replace("ö", "oe").replace("ä", "ae").replace("ü","ue").split())
        return {word for word in s if len(word) >= 3}
    
    targets = normalize_split(city)
    for possible_city in possible_cities:
        possible_substrings = normalize_split(possible_city)

        if targets & possible_substrings:
            return possible_city
    
    return None


AVOID_STR= ["please delete - bitte loeschen", "Nicht", "mehr aktiv", "", "gelöscht", "Hh Admi-Testkasse", "12345"]
def prepare_stations(plz_region_file : str, stations_dataset :str, output :str, just_trim : bool = True):

    if just_trim:
        with open(output,'w+') as outfile, open(stations_dataset, mode='r', newline='') as infile:
            writer = csv.DictWriter(outfile, fieldnames=columns_to_keep) 
            reader = csv.DictReader(infile) 

            writer.writeheader()
            for row in reader:
                writer.writerow(filter_row(row))
            
        return 


    #use official dataset of Germany's regions
    plz_to_cities : dict[str, list[str]] = {}
    with open(plz_region_file, 'r') as input_plz_to_city:
            reader_plz_city = csv.DictReader(input_plz_to_city)  
            for row in reader_plz_city:
                plz = row['plz']
                city = row['ort']

                if plz in plz_to_cities:
                    if city not in plz_to_cities[plz]:
                        plz_to_cities[plz].append(city)
                else:
                    plz_to_cities[plz] = [city]


    with open(output,'w+') as outfile, open(stations_dataset, mode='r', newline='') as infile:
        writer = csv.DictWriter(outfile, fieldnames=columns_to_keep)
        writer.writeheader()

        invalid_plz_unknown_city : list[RowType] = [] 
        reader = csv.DictReader(infile) 
        for row in reader:
            plz = row['post_code']
            city = row['city']

            if not plz.isdigit() or plz in ['12345', '00000']:
                print(f"Skipping {to_str(row)}")
                continue
                

            if len(plz) < 5:
                plz = "0"*(5-len(plz)) + plz

            if plz in plz_to_cities: #valid post_code
                if len(plz_to_cities[plz]) == 1: 
                    row['city'] = plz_to_cities[plz][0] #only one city with that postcode
                else:
                    #try to find a city name (but not important -> cannot be used in aggregations)
                    match = find_best_match(city,plz_to_cities[plz])
                    if match:
                        row['city'] = match

                writer.writerow(filter_row(row))

            else:
                invalid_plz_unknown_city.append(filter_row(row))
       
              

        not_good : list[RowType] =[]
        print(f"\n{len(invalid_plz_unknown_city)} cities with invalid plz:")
        for s in invalid_plz_unknown_city:
            print(f"Trying to fix: {to_str(s)}")
            match = query_location(float(s['latitude']),float(s['longitude']))
            if match:
                print(f"\tFOUND: {match[0]}, {match[1]} for {s['post_code']}, {s['city']}")
                s['post_code'] = match[0]
                s['city'] = match[1]
                writer.writerow(filter_row(s))
            else:
                print(f"\tNOT FOUND: for {s['post_code']}, {s['city']}")
                not_good.append(s)
    
        if len(not_good) == 0:
            print("OK")
        else:
            print(f"\nSTILL PROBLEMS: {len(not_good)}")
            for s in not_good:
                print(to_str(s)) 
    

def prepare_regions(plz_region_file : str, output_file : str):
    new_mapping: dict[str,str] = {'post_code' : 'plz', 'cities' : 'ort', 'landkreis' : 'landkreis', 'bundesland' : 'bundesland' }
    with open(plz_region_file, 'r') as input, open(output_file,'w+') as outfile:
        reader = csv.DictReader(input)  

        writer = csv.DictWriter(outfile, fieldnames=list(new_mapping.keys()))
        writer.writeheader()

        for row in reader:
            writer.writerow({new_key : row.get(old_key, '') for new_key,old_key in new_mapping.items()})



REGIONS_OUTPUT="regions_ready.csv"
STATION_OUTPUT="stations_ready.csv"

def main():
    parser = argparse.ArgumentParser(description="Usage: <station_file> <region_file> [-c (--clean)]")
    parser.add_argument('station_file', type=str, help="station input file")
    parser.add_argument('region_file', type=str, help="region input file")
    parser.add_argument('-c', '--clean', action='store_true', help="Execute stations cleaning (otherwise only trimming)")
    args = parser.parse_args()
    just_trim = not args.clean 
    
    
    prepare_regions(args.region_file,os.path.join(os.path.dirname(args.region_file),REGIONS_OUTPUT))
    print(f'Regions dataset ready in {REGIONS_OUTPUT}')
    
    prepare_stations(args.region_file,args.station_file,os.path.join(os.path.dirname(args.station_file),STATION_OUTPUT),just_trim)
    print(f'Regions dataset ready {"(and cleared)" if not just_trim else ""} in {STATION_OUTPUT}')
    

if __name__ == "__main__":
    main()