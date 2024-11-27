import sys
import pandas as pd
import matplotlib.pyplot as plt
import os
import psycopg as pg
from datetime import datetime
import numpy as np

import geopandas as gpd
import folium
import branca.colormap as cm
from folium.utilities import JsCode
from folium.elements import EventHandler,Element

USER = 'client'
USER_PSWD = 'client'
DB = 'client'
PORT=5432

OUTPUT_FOLDER="plots" #relative path
POSSIBLE_FUELS= ['diesel', 'e5', 'e10']

DIESEL_QUERY_GERMANY="../sql/queries/closest_price.sql"    #relative path
DIESEL_QUERY_CITY="../sql/queries/closest_price_city.sql"    #relative path
DATE = datetime(2024,4,30,12,30)
INTERVAL="30 minutes"


def get_real_path(relative_path : str) -> str:
    script_dir = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(script_dir, relative_path)

def get_output_dir() -> str:
    output_dir = get_real_path(OUTPUT_FOLDER)
    os.makedirs(output_dir, exist_ok=True)
    return output_dir


def filter_outliers(df : pd.DataFrame, column : str) -> pd.DataFrame:
    mean_price = df[column].mean()
    std_price = df[column].std()
    z_threshold = 3

    df['z_score'] = (df[column] - mean_price) / std_price
    df_filtered = df[df['z_score'].abs() <= z_threshold]
    return df_filtered

def column_from_fuel(fuel : str) -> str:
    return f'{fuel}_price'



def query_fuel_germany(fuel : str = 'diesel') -> pd.DataFrame:
    query = open(get_real_path(DIESEL_QUERY_GERMANY),"r").read()
    if fuel != 'diesel':
        query = query.replace("diesel",fuel)
    
    with pg.connect(f"host=localhost port={PORT} user={USER} password={USER_PSWD} dbname={DB}") as conn:
        df = pd.read_sql(query,conn, params=(DATE,INTERVAL))
    
    return df

def query_fuel_city(city : str, fuel : str = 'diesel')  -> pd.DataFrame:
    query = open(get_real_path(DIESEL_QUERY_CITY),"r").read()
    if fuel != 'diesel':
        query = query.replace("diesel",fuel)
    
    with pg.connect(f"host=localhost port={PORT} user={USER} password={USER_PSWD} dbname={DB}") as conn:
        df = pd.read_sql(query,conn, params=(city,DATE,INTERVAL))

    
    
    return df



def plot_hg(df : pd.DataFrame, fuel : str,  base_name : str):
    column = column_from_fuel(fuel)

    num_bins = 30
    counts, bin_edges = np.histogram(df[column], bins=num_bins)
    bin_midpoints = (bin_edges[:-1] + bin_edges[1:]) / 2

    plt.figure(figsize=(10, 6))
    plt.hist(df[column], bins=num_bins, color='skyblue', edgecolor='black')
    plt.plot(bin_midpoints, counts, marker='o', linestyle='-', color='b')

    for x, y in zip(bin_midpoints, counts):
        plt.text(x, y, str(x), ha='center', va='bottom', fontsize=9, color='blue')

    plt.xlabel(f'{fuel} Price')
    plt.ylabel('Number of Stations')
    plt.title('Number of Stations by Diesel Price Range')
    
    plt.savefig(os.path.join(get_output_dir(),f"{base_name}_{fuel}.png"))


def plot_map(df : pd.DataFrame,fuel : str):
    price_col = column_from_fuel(fuel)

    

    m = folium.Map(location=(51.1657, 10.4515),zoom_start=7, control_scale=True, tiles="CartoDB Positron")

    df_filtered = filter_outliers(df,column_from_fuel(fuel))
    min_price = df_filtered[price_col].min()
    max_price = df_filtered[price_col].max()


    interval_10 = min_price + 0.10 * (max_price - min_price)
    interval_30 = min_price + 0.30 * (max_price - min_price)
    interval_70 = min_price + 0.70 * (max_price - min_price)

    #colormap = cm.StepColormap(["green", "yellow", "red"],vmin=min_price, vmax=max_price, index=[interval_10, interval_30, interval_70])
    colormap = cm.LinearColormap(["green", "yellow", "red"], vmin=min_price, vmax=max_price)

    colormap.caption = f"{fuel.capitalize()} Price"
    colormap.add_to(m)


    # plz_shape_df = gpd.read_file(get_real_path('../data/plz-5stellig.shp'), dtype={'plz': str})
    # unique_post_codes = df['post_code'].unique()
    # plz_involved = plz_shape_df[plz_shape_df['plz'].isin(unique_post_codes)]

    # for _, row in plz_involved.iterrows():
    #     folium.GeoJson(
    #         row['geometry'],
    #         style_function=lambda x: {
    #             'fillColor': '#add8e6', 
    #             'color': '#add8e6',
    #             'weight': 1,
    #             'fillOpacity': 0.5
    #         }
    #     ).add_to(m)

    def dynamic_radius(zoom_level):
        return zoom_level*2
    
    r = JsCode("""
               function highlight(e) {
                    alert("ciao");
               }
        """)

    initial_radius = 1
    # Plot each point with color scaled by diesel price
    for idx, row in df.iterrows():
        color = colormap(row[price_col])
        f = folium.CircleMarker(
            location=[row['latitude'], row['longitude']],
            tooltip=row['name'],
            fill=True,
            fill_opacity=1,
            opacity=1,
            fill_color=color,
            color=color,
            radius=1,
            popup=f"{fuel.capitalize()} Price: {row[price_col]}\n\nid:({row['station_uuid']})",
        ).add_to(m)


        f.add_child(EventHandler("click",r))

    output_dir = get_real_path(OUTPUT_FOLDER)
    os.makedirs(output_dir, exist_ok=True)
    m.save(os.path.join(output_dir,f"{fuel}_stations_germany.html"))


def main():
    if len(sys.argv) != 2:
        print(f"Usage: python {sys.argv[0]} <fuel>")
        sys.exit(1)
    
    if sys.argv[1] not in POSSIBLE_FUELS:
        print(f"{sys.argv[1]} is not a valid fuel")
        sys.exit(1)

    fuel = sys.argv[1]
    df = query_fuel_city("München", fuel)
    #df = query_fuel_germany(fuel)

    plot_hg(df, fuel, "stations_per_price_germany")
    df_filtered = filter_outliers(df,column_from_fuel(fuel))
    plot_hg(df_filtered, fuel ,"stations_per_price_germany_filtered")
    
    plot_map(df,fuel)

if __name__ == "__main__":
    main()