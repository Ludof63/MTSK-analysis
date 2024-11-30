import sys
import pandas as pd
import matplotlib.pyplot as plt
import os
import psycopg as pg
from datetime import datetime
import numpy as np


USER = 'client'
USER_PSWD = 'client'
DB = 'client'
PORT=5432

OUTPUT_FOLDER="plots" #relative path
POSSIBLE_FUELS= ['diesel', 'e5', 'e10']

DIESEL_QUERY="../sql/queries/closest_price_city.sql"    #relative path
DATE = datetime(2024,4,30,12,30)
INTERVAL="30 minutes"


def get_real_path(relative_path : str) -> str:
    script_dir = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(script_dir, relative_path)

def station_count_by_price_range(city : str, fuel : str = 'diesel'):
    query = open(get_real_path(DIESEL_QUERY),"r").read()
    if fuel != 'diesel':
        query = query.replace("diesel",fuel)
    
    with pg.connect(f"host=localhost port={PORT} user={USER} password={USER_PSWD} dbname={DB}") as conn:
        df = pd.read_sql(query,conn, params=(city,DATE,INTERVAL))


    bins  = np.arange(1.55, 2.30, 0.05)

    plt.figure(figsize=(10, 6)) 
    plt.hist(df[f'{fuel}_price'],bins=bins, edgecolor='black')

    plt.xlabel(f'{fuel.capitalize()} Price')
    plt.ylabel('Number of Stations')
    plt.title(f'Distribution of {fuel.capitalize()} Prices Across Stations in {city.capitalize()} ({DATE})')

    output_dir = get_real_path(OUTPUT_FOLDER)
    os.makedirs(output_dir, exist_ok=True)
    plt.savefig(os.path.join(output_dir,f"station_count_by_price_range_{city}_{fuel}.png"))
    


def main():
    if len(sys.argv) != 3:
        print(f"Usage: python {sys.argv[0]} <city> <fuel>")
        sys.exit(1)
    
    if sys.argv[2] not in POSSIBLE_FUELS:
        print(f"{sys.argv[2]} is not a valid fuel")
        sys.exit(1)
    
    station_count_by_price_range(sys.argv[1].title(),sys.argv[2])

if __name__ == "__main__":
    main()