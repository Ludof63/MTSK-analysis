import csv
import os
from datetime import datetime
from typing import Any, TypeAlias
import requests
import random
import argparse
import json



RowType : TypeAlias =  dict[str | Any, str | Any]

def get_real_path(relative_path : str) -> str:
    script_dir = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(script_dir, relative_path)


def is_point_in_germany(row : RowType):
    lat, lon = float(row['latitude']), float(row['longitude'])

    min_lat, max_lat = 47.2, 55.1
    min_lon, max_lon = 5.9, 15.0

    return min_lat <= lat <= max_lat and min_lon <= lon <= max_lon



#---------------------------------------------------------------------------------
def query_osm(api_type : str, params : dict[str,Any]) -> Any | Exception:
    url = f"https://nominatim.openstreetmap.org/{api_type}"
    user = random.choice(["pippo", "pluto", "paperino"])
    
    try:
        response = requests.get(url, params=params, headers={"User-Agent": user})
        print(f"Sending: {response.url}")
        response.raise_for_status()
        data = response.json()
        return data
        
    except requests.RequestException as e:
        print(f"Error querying the Nominatim API: {e}")
        return Exception(e)

def osm_search(params : dict[str,Any]) -> Any | Exception:
    return query_osm("search",params)

def osm_reverse(params : dict[str,Any]) -> Any | Exception:
    return query_osm("reverse",params)



def query_for_postcode_city(lat: float, lon:float) -> tuple[str,str] | None:
    params = {
        'lat': lat,
        'lon': lon,
        "country": "Germany",
        "format": "json",
        "addressdetails": 1
    }

    data = osm_reverse(params)
    if isinstance(data,Exception):
        return None

    if 'address' in data:
        if 'town' in data['address']:
            return data['address']['postcode'],data['address']['town']

        if 'village' in data['address']:
            return data['address']['postcode'],data['address']['village']
        
        if 'city' in data['address']:
            return data['address']['postcode'],data['address']['city']

    return None


def query_for_coordinates(post_code : str, street : str) -> tuple[float, float] | None:
    params = {
        'postalcode': post_code,
        'street': street,
        "country": "Germany",
        "format": "json",
        "addressdetails": 1
    }

    data = osm_search(params)
    if isinstance(data,Exception):
        return None
        
    for el in data:
        if 'lat' in el and 'lon' in el:
            lat, lon = float(el['lat']),float(el['lon'])
            return lat,lon
        
    if street != '':
        return query_for_coordinates(post_code,'') #street not found, just take coords of post_code
    else:
        return None
    
#---------------------------------------------------------------------------------


columns_to_keep = ['uuid', 'name', 'brand', 'street', 'house_number', 'post_code', 'city', 'latitude', 'longitude']
stations_header = columns_to_keep + ['always_open']
times_header = ['uuid', 'days', 'open_at', 'close_at']


TIMES : list[RowType] = []


def add_stations_time(st_time, stations_id) -> bool:
    if 'openingTimes' not in st_time:
        return True #always open
    
    for t in st_time['openingTimes']:
        days = int(t['applicable_days'])
        assert(len(t['periods']) == 1)
        open,close = t['periods'][0]['startp'], t['periods'][0]['endp']
        if close in ['00:00','24:00']:
            close = '23:59:59'
        TIMES.append({'uuid': stations_id, 'days': days, 'open_at': open, 'close_at': close})
        #print(f"{days} -> [{open}, {close}]")

    return False
    #input("Continue?")


def filter_row(row : RowType) -> RowType:
    filter_row = {key : row.get(key, '') for key in columns_to_keep}
    filter_row['brand'] = filter_row['brand'].title()

    filter_row['always_open'] = add_stations_time(json.loads(row['openingtimes_json']), filter_row['uuid'])

    return filter_row
    

def to_str_1(row : RowType) -> str:
    columns_to_print = columns_to_keep = ['post_code', 'city']
    s =", ".join([f"{key} : {row.get(key,'')}" for key in columns_to_print])
    s += f", coords: ({row['latitude']},{row['longitude']})"
    return s

def to_str_2(row : RowType) -> str:
    columns_to_print = columns_to_keep = ['post_code', 'city', 'street', 'house_number']
    s =", ".join([f"{key} : {row.get(key,'')}" for key in columns_to_print])
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




def prepare_stations(plz_region_file : str, stations_dataset :str, output :str):
    tmp_out_file = 'data_temp.csv'

    just_trim = False
    if just_trim:
        with open(tmp_out_file,'w+') as outfile, open(stations_dataset, mode='r', newline='') as infile:
            writer = csv.DictWriter(outfile, fieldnames=stations_header) 
            reader = csv.DictReader(infile) 
            writer.writeheader()
        
            for row in reader:
                writer.writerow(filter_row(row))


        os.replace(tmp_out_file,output)
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


    
    with open(tmp_out_file,'w+') as outfile, open(stations_dataset, mode='r', newline='') as infile:
        writer = csv.DictWriter(outfile, fieldnames=stations_header)
        writer.writeheader()

        invalid_plz_unknown_city : list[RowType] = [] 
        invalid_coord : list[RowType] = []
        reader = csv.DictReader(infile) 
        for row in reader:
            plz = row['post_code']
            city = row['city']

            if not plz.isdigit() or plz in ['12345', '00000']:
                print(f"Skipping {to_str_1(row)}")
                continue
                

            if len(plz) < 5:
                plz = "0"*(5-len(plz)) + plz

            valid_coords = is_point_in_germany(row)


            if plz in plz_to_cities: #valid post_code
                if len(plz_to_cities[plz]) == 1: 
                    row['city'] = plz_to_cities[plz][0] #only one city with that postcode
                else:
                    #try to find a city name (but not important -> cannot be used in aggregations)
                    match = find_best_match(city,plz_to_cities[plz])
                    if match:
                        row['city'] = match
                
                if valid_coords:
                    writer.writerow(filter_row(row))
                else:
                    invalid_coord.append(row)

            else:
                if valid_coords:
                    invalid_plz_unknown_city.append(row)
                else:
                    print(f"Skipping {to_str_1(row)} -> both post_code and coords wrong")
    

        #fixing phase, using OSM ---------------------------------

        still_problems : list[RowType] =[]

        print(f"\n #station with invalid coords:  {len(invalid_coord)} ---------------")
        for s in invalid_coord:
            print(f"Trying to find coord for: {to_str_2(s)}")
            match = query_for_coordinates(s['post_code'],s['street'])

            if match:
                print(f"\tFOUND coord: {match[0]}, {match[1]} for {s['post_code']}, {s['street']}")
                s['latitude'], s['longitude'] = match
                writer.writerow(filter_row(s))
            else:
                print(f"\tNOT FOUND coords: for {s['post_code']}, {s['street']}")
                still_problems.append(s)

        print(f"\n #station with invalid plz:  {len(invalid_plz_unknown_city)} --------------")
        for s in invalid_plz_unknown_city:
            print(f"Trying to find plz,city for: {to_str_1(s)}")
            match = query_for_postcode_city(float(s['latitude']),float(s['longitude']))

            if match:
                print(f"\tFOUND: {match[0]}, {match[1]} for {s['post_code']}, {s['city']}")
                s['post_code'], s['city'] = match
                writer.writerow(filter_row(s))
            else:
                print(f"\tNOT FOUND: for {s['post_code']}, {s['city']}")
                still_problems.append(s)
        
        if len(still_problems) == 0:
            print("OK")
        else:
            print(f"\nSTILL PROBLEMS: {len(still_problems)}")
            for s in still_problems:
                print(to_str_1(s)) 

    os.replace(tmp_out_file,output)
    

def prepare_regions(plz_region_file : str, output_file : str):
    new_mapping: dict[str,str] = {'post_code' : 'plz', 'cities' : 'ort', 'landkreis' : 'landkreis', 'bundesland' : 'bundesland' }
    with open(plz_region_file, 'r') as input, open(output_file,'w+') as outfile:
        reader = csv.DictReader(input)  
              
        writer = csv.DictWriter(outfile, fieldnames=list(new_mapping.keys()))
        writer.writeheader()

        for row in reader:
            writer.writerow({new_key : row.get(old_key, '') for new_key,old_key in new_mapping.items()})



STATION_OUTPUT="stations.csv"
TIMES_OUTPUT="stations_times.csv"

def main():
    parser = argparse.ArgumentParser(description="Usage: <station_file> <region_file>")
    parser.add_argument('station_file', type=str, help="station input file")
    parser.add_argument('region_file', type=str, help="region input file")
    args = parser.parse_args()

    
    prepare_stations(args.region_file,args.station_file,os.path.join(os.path.dirname(args.station_file),STATION_OUTPUT))
    print(f'Stations dataset ready in {STATION_OUTPUT}')

    with open(os.path.join(os.path.dirname(args.station_file),TIMES_OUTPUT),'w+') as outfile:
        writer = csv.DictWriter(outfile, fieldnames=times_header) 
        writer.writeheader()
        
        for row in TIMES:
            writer.writerow(row)
    print(f'Stations Times ready in {TIMES_OUTPUT}')

    

if __name__ == "__main__":
    main()