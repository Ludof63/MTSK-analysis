import folium.plugins
import pandas as pd
import matplotlib.pyplot as plt
import os
import psycopg as pg
from datetime import datetime
import numpy as np

import folium
import branca.colormap as cm
from folium.plugins import MarkerCluster
from typing import List
import re

def get_real_path(relative_path : str) -> str:
    script_dir = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(script_dir, relative_path)


USER = 'client'
USER_PSWD = 'client'
DB = 'client'
PORT=5432

OUTPUT_FOLDER = get_real_path("plots")
POSSIBLE_FUELS= ['diesel', 'e5', 'e10']

GRANULARITY_COLOR_AGGREGATE=10
AGGREGATE_UNTIL_ZOOM = 9

QUERY_FILE =



def run_query() -> pd.DataFrame:
    query = open(get_real_path(QUERY_FILE),"r").read()
    with pg.connect(f"host=localhost port={PORT} user={USER} password={USER_PSWD} dbname={DB}") as conn:
        df = pd.read_sql(query,conn)
    
    return df



def plot_hg(df : pd.DataFrame, x_col : str, y_col : str):
    num_bins = 50
    counts, bin_edges = np.histogram(df[y_col], bins=num_bins)
    bin_midpoints = (bin_edges[:-1] + bin_edges[1:]) / 2

    plt.figure(figsize=(10, 6))
    plt.hist(df[x_col], bins=num_bins, color='skyblue', edgecolor='black')
    plt.plot(bin_midpoints, counts, marker='o', linestyle='-', color='b')

    # for x, y in zip(bin_midpoints, counts):
    #     plt.text(x, y, str(x), ha='center', va='bottom', fontsize=9, color='blue')

    plt.xlabel(f'{fuel} Price')
    plt.ylabel('Number of Stations')
    plt.title(f'Number of Stations by {fuel} Price Range')
    
    plt.savefig(os.path.join(OUTPUT_FOLDER,f"hg_{fuel}.png"))


def plot_map():

    m = folium.Map(tiles=None,location=(51.1657, 10.4515),zoom_start=7,control_scale=True)
    folium.TileLayer("CartoDB Positron",control=False).add_to(m)

    colormap = cm.LinearColormap(colors=['green', 'yellow', 'red'], vmin=-3, vmax=3)
    colormap.caption = f"Deviation from mean"
    colormap.add_to(m)

    def get_color(z_score):
        if z_score > 3:
            return 'black'
        if z_score < -3:
            return 'pink'
        return colormap(z_score)

    df = run_query()

    mean_value = df[VALUE_COL].mean()
    std_dev = df[VALUE_COL].std()
    print(f"Mean: {mean_value}\nStdDev: {std_dev}")

    for idx, row in df.iterrows():
        z_score = (row[VALUE_COL] - mean_value) / std_dev
        color = get_color(z_score)

        marker = folium.CircleMarker(
            location=[row['latitude'], row['longitude']],
            tooltip=row['station_uuid'],
            fill=True,
            fill_opacity=1,
            opacity=1,
            fill_color=color,
            color=color,
            radius=2,
            popup=f"id:{row['station_uuid']}\nval:{row[VALUE_COL]}\ncity:{row['city']}\nbrand:{row['brand']})"
        )
        marker.add_to(m)

    
    folium.LayerControl().add_to(m)
    print("Plotting done")

    
    outfile ="update_frequencies.html"
    m.save(os.path.join(OUTPUT_FOLDER,outfile))
    print(f"Map saved in {outfile}")


def main():    
    os.makedirs(OUTPUT_FOLDER, exist_ok=True)
    plot_map()

if __name__ == "__main__":
    main()
