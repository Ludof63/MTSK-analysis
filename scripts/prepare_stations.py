import csv
import os
from datetime import time, datetime
from typing import Any, TypeAlias
import requests
import random
import argparse
import json
import math


RowType : TypeAlias =  dict[str | Any, str | Any]
COLUMNS_TO_KEEP = ['uuid', 'name', 'brand', 'street', 'house_number', 'post_code', 'city', 'latitude', 'longitude', 'first_active']
STATIONS_HEADER = COLUMNS_TO_KEEP + ['always_open']
TIMES_HEADER = ['uuid', 'days', 'open_at', 'close_at']

AVOID_STR= ["please delete - bitte loeschen", "Nicht", "mehr aktiv", "", "gelöscht", "Hh Admi-Testkasse", "12345"]
TIMES : list[RowType] = []

STATION_OUTPUT="stations.csv"
TIMES_OUTPUT="stations_times.csv"
JUST_TRIM= False

#----------------------------------------------------------
def get_real_path(relative_path : str) -> str:
    script_dir = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(script_dir, relative_path)


def is_point_in_germany(row : RowType):
    lat, lon = float(row['latitude']), float(row['longitude'])
    min_lat, max_lat = 47.2, 55.1
    min_lon, max_lon = 5.9, 15.0

    return min_lat <= lat <= max_lat and min_lon <= lon <= max_lon

def to_str_1(row : RowType) -> str:
    columns_to_print = columns_to_keep = ['post_code', 'city']
    s =", ".join([f"{key} : {row.get(key,'')}" for key in columns_to_print])
    s += f", coords: ({row['latitude']},{row['longitude']})"
    return s

def to_str_2(row : RowType) -> str:
    columns_to_print = columns_to_keep = ['uuid','post_code', 'city', 'street']
    s =", ".join([f"{key} : {row.get(key,'')}" for key in columns_to_print])
    s += f", coords: ({row['latitude']},{row['longitude']})"
    return s

def find_best_match(city : str, possible_cities : list[str]) -> str | None:
    def normalize_split(city_str : str):
        s = set(city_str.title().replace("-", " ").replace("/", " ").replace("ß", "ss").replace("ö", "oe").replace("ä", "ae").replace("ü","ue").split())
        return {word for word in s if len(word) >= 3}
    
    if len(possible_cities) == 0:
        return possible_cities[0]
    
    targets = normalize_split(city)
    for possible_city in possible_cities:
        possible_substrings = normalize_split(possible_city)

        if targets & possible_substrings:
            return possible_city
    
    return None


#---------------------------------------------------------------------------------
def query_osm(api_type : str, params : dict[str,Any]) -> Any | Exception:
    url = f"https://nominatim.openstreetmap.org/{api_type}"
    user = random.choice(["pippo", "pluto", "paperino"])
    
    try:
        response = requests.get(url, params=params, headers={"User-Agent": user})
        print(f"\tSending: {response.url}")
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
    params = {'lat': lat,'lon': lon,"country": "Germany", "format": "json", "addressdetails": 1}

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


def query_for_coordinates(post_code : str  = "", city : str = "", street : str = "") -> tuple[float, float] | None:
    params = {'postalcode': post_code, 'city': city, 'street': street,"country": "Germany","format": "json","addressdetails": 1}

    data = osm_search(params)
    if isinstance(data,Exception):
        return None
        
    for el in data:
        if 'lat' in el and 'lon' in el:
            lat, lon = float(el['lat']),float(el['lon'])
            return lat,lon
        
    if post_code != "" and street != "":
        return query_for_coordinates(post_code=post_code) #street not found, just take coords of post_code
    else:
        return None
    
#---------------------------------------------------------------------------------

def add_stations_time(st_time, stations_id):
    def to_time(time_str : str) -> time:
        try:
            return datetime.strptime(time_str, "%H:%M:%S").time()
        except ValueError:
            return datetime.strptime(time_str, "%H:%M").time()
    
    intervals : list[tuple[int,time,time]] = []
    for t in st_time['openingTimes']:
        assert(len(t['periods']) == 1)
        if t['periods'][0]['endp'] in ['00:00','24:00']:
            t['periods'][0]['endp'] = '23:59:59'
        intervals.append((int(t['applicable_days']),to_time(t['periods'][0]['startp']) , to_time(t['periods'][0]['endp'])))

    intervals.sort(key= lambda x: x[0], reverse=True)

    merged : list[tuple[int,time,time]]  = [intervals[0]]
    for days, open, close in intervals[1:]:
        last_days, last_open, last_close = merged[-1]
        if (days & last_days) > 0:
            merged[-1] = (last_days | days, min(last_open, open), max(last_close, close))
        else:
            merged.append((days, open,close))
            
    for d,o,c in merged:       
        TIMES.append({'uuid': stations_id, 'days': d, 'open_at': o, 'close_at': c})



def parse_row(row : RowType) -> RowType:
        filter_row = {key : row.get(key, '') for key in COLUMNS_TO_KEEP}

        openingTimes = json.loads(row['openingtimes_json'])
        filter_row['always_open'], filter_row['brand']  = 'openingTimes' not in openingTimes , filter_row['brand'].title()
        if not filter_row['always_open']:
            add_stations_time(openingTimes, filter_row['uuid'])

        return filter_row


def are_coords_correct(row : RowType) -> bool:
    if math.isclose(float(row['latitude']), 51.163375, rel_tol=0, abs_tol=0.001) and math.isclose(float(row['longitude']), 10.447683, rel_tol=0, abs_tol=0.001):
        return False
    
    return is_point_in_germany(row)

def prepare_stations(stations_dataset :str, plz_region_file : str,  output :str):
    tmp_out_file = 'data_temp.csv'
    plz_to_cities : dict[str, list[str]] = {}
    with open(plz_region_file, 'r') as input_plz_to_city:
            reader_plz_city = csv.DictReader(input_plz_to_city)  
            for row in reader_plz_city:
                plz, city = row['plz'], row['ort']
        
                if plz in plz_to_cities:
                    if city not in plz_to_cities[plz]:
                        plz_to_cities[plz].append(city)
                else:
                    plz_to_cities[plz] = [city]



    
    latest_active : str = ""
    with open(tmp_out_file,'w+') as outfile:
        writer = csv.DictWriter(outfile, fieldnames=STATIONS_HEADER)
        writer.writeheader()

        invalid_plz : list[RowType] = [] 
        invalid_coord : list[RowType] = []
        invalid_plz_coord : list[RowType] = []

        with open(stations_dataset, mode='r', newline='') as infile:
            reader = csv.DictReader(infile) 
            for row in reader:                    
                latest_active = row['first_active']
                plz, city = row['post_code'], row['city']

                if not plz.isdigit() or plz in ['12345', '00000']:
                    print(f"Skipping {to_str_1(row)}")
                    continue
                                
                if len(plz) < 5:
                    plz = "0"*(5-len(plz)) + plz

                if are_coords_correct(row):
                    if plz in plz_to_cities: #plz is correct
                        match = find_best_match(city,plz_to_cities[plz]) #find best candidate
                        row['city'] = match if match else row['city'] #otherwise keep old
                        writer.writerow(parse_row(row)) #WRITE TO RESULT
                    else:
                        invalid_plz.append(row) #NEED TO CORRECT PLZ?
                else:
                    if plz in plz_to_cities: #plz is correct
                        invalid_coord.append(row) #NEED TO CORRECT COORDS       
                    else:
                        invalid_plz_coord.append(row) #NEED TO CORRECT

        
        #fixing phase, using OSM ---------------------------------
        DO_FIX_COORDS, KEEP_INVALID_COORDS= True, False
        DO_FIX_PLZ, KEEP_INVALID_PLZ= True, False
        DO_FIX_PLZ_COORDS, KEEP_INVALID_PLZ_COORDS= True, False
        
        okay_fixes, not_okay_fixes = 0,0

        print(f"\nINVALID COORDS: {len(invalid_coord)}")
        for row in invalid_coord:
            print(f"Invalid coords: {to_str_2(row)}")
            if DO_FIX_COORDS:
                match = query_for_coordinates(row['post_code'], row['city'], row['street'])

                if match:
                    print(f"\tFOUND coord: {match[0]}, {match[1]}")
                    row['latitude'], row['longitude'] = match
                    okay_fixes += 1
                    
                else:
                    print(f"\tNOT FOUND coords!")
                    not_okay_fixes += 1
                
                if match or KEEP_INVALID_COORDS:
                    writer.writerow(parse_row(row)) #WRITE TO RESULT

            elif KEEP_INVALID_COORDS:
                    writer.writerow(parse_row(row)) #WRITE TO RESULT
                 
        
        print(f"\nINVALID PLZ: {len(invalid_plz)}")
        for row in invalid_plz:
            print(f"Invalid plz: {to_str_2(row)}")
            if DO_FIX_PLZ:
                match = query_for_postcode_city(float(row['latitude']),float(row['longitude']))
                            
                if match:
                    print(f"\tFOUND zip,city: {match[0]}, {match[1]}")
                    row['post_code'], row['city'] = match
                    okay_fixes += 1
                else:
                    print(f"\tNOT FOUND info!")
                    not_okay_fixes += 1
                
                if match or KEEP_INVALID_PLZ:
                    writer.writerow(parse_row(row)) #WRITE TO RESULT

            elif KEEP_INVALID_PLZ:
                    writer.writerow(parse_row(row)) #WRITE TO RESULT
             

        print(f"\nINVALID PLZ AND COORD: {len(invalid_plz_coord)}")
        for row in invalid_plz_coord:
            print(f"Invalid plz and coord: {to_str_2(row)}")
            if DO_FIX_PLZ_COORDS:
                match_coords = query_for_coordinates(city=row['city'], street=row['street'])
                if match_coords:
                    print(f"\tFOUND coords: {match_coords[0]}, {match_coords[1]}")
                    row['latitude'], row['longitude'] = match_coords
                    match_info = query_for_postcode_city(float(row['latitude']),float(row['longitude']))
                    if match_info:
                        print(f"\tFOUND zip,city: {match_info[0]}, {match_info[1]}")
                        row['post_code'], row['city'] = match_info

                    okay_fixes += 1
                else:
                    print(f"\tNOT FOUND coords!")
                    not_okay_fixes += 1

                if match_coords or KEEP_INVALID_PLZ_COORDS:
                    writer.writerow(parse_row(row)) #WRITE TO RESULT

            elif KEEP_INVALID_PLZ_COORDS:
                    writer.writerow(parse_row(row)) #WRITE TO RESULT

    print(f"Status of Fixed: OK: {okay_fixes} , NOT OKAY: {not_okay_fixes}")
    print(f"Last station insert in dataset active from {latest_active}")
    os.replace(tmp_out_file,output)
        


def main():
    parser = argparse.ArgumentParser(description="Usage: <station_file> <region_file>")
    parser.add_argument('station_file', type=str, help="station input file")
    parser.add_argument('region_file', type=str, help="region input file")
    args = parser.parse_args()

    stations_output_file = os.path.join(os.path.dirname(args.station_file),STATION_OUTPUT)
    prepare_stations(args.station_file,args.region_file, stations_output_file)
    print(f'Stations dataset ready in {stations_output_file}')

    times_output_file = os.path.join(os.path.dirname(args.station_file),TIMES_OUTPUT)
    with open(times_output_file,'w+') as outfile:
        writer = csv.DictWriter(outfile, fieldnames=TIMES_HEADER) 
        writer.writeheader()
        
        for row in TIMES:
            writer.writerow(row)

    print(f'Stations Times ready in {times_output_file}')

    

main()