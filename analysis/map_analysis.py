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

CLOSEST_PRICE="../sql/queries/closest_price.sql"    #relative path

DATE = datetime(2024,4,30,12,30)
INTERVAL="30 minutes"



def query_closest_price(fuel : str = 'diesel') -> pd.DataFrame:
    query = open(get_real_path(CLOSEST_PRICE),"r").read()
    if fuel != 'diesel':
        query = query.replace("diesel",fuel)
    
    with pg.connect(f"host=localhost port={PORT} user={USER} password={USER_PSWD} dbname={DB}") as conn:
        df = pd.read_sql(query,conn, params=(DATE,INTERVAL))
    
    return df



def plot_hg(df : pd.DataFrame, fuel : str):
    num_bins = 50
    counts, bin_edges = np.histogram(df[fuel], bins=num_bins)
    bin_midpoints = (bin_edges[:-1] + bin_edges[1:]) / 2

    plt.figure(figsize=(10, 6))
    plt.hist(df[fuel], bins=num_bins, color='skyblue', edgecolor='black')
    plt.plot(bin_midpoints, counts, marker='o', linestyle='-', color='b')

    # for x, y in zip(bin_midpoints, counts):
    #     plt.text(x, y, str(x), ha='center', va='bottom', fontsize=9, color='blue')

    plt.xlabel(f'{fuel} Price')
    plt.ylabel('Number of Stations')
    plt.title(f'Number of Stations by {fuel} Price Range')
    
    plt.savefig(os.path.join(OUTPUT_FOLDER,f"hg_{fuel}.png"))



# def get_hex(colors):
#     return ["#%02x%02x%02x" % tuple(int(u * 255.9999) for u in c[:3]) for c in colors]


colormap = cm.LinearColormap(colors=['green', 'yellow', 'red'], vmin=-3, vmax=3)
colormap.caption = f"Deviation from mean"

step_cm = colormap.to_step(GRANULARITY_COLOR_AGGREGATE)
color_switch = "if (score < -3) {color = 'pink'; }\n"
for i in step_cm.index[1 : ]:
    color_switch += f"else if (score < {i}) {{ color = '{step_cm.rgba_hex_str(i)}';}}\n"
color_switch += "else { color = 'blak'; }"

js_func = f'''

        function(cluster) {{
            var childCount = cluster.getChildCount();

            var c = ' marker-cluster-';
            if (childCount < 10) {{
                c += 'small';
            }} else if (childCount < 100) {{
                c += 'medium';
            }} else {{
                c += 'large';
            }}


            var markers = cluster.getAllChildMarkers();
            var total = 0;

            markers.forEach(function(marker) {{total += marker.options['z_score'];}});
            var score = total / childCount;


            var color = "";
            {color_switch}

            return new L.DivIcon({{ html: '<div style="background-color:' + color + '";><span>' + childCount + '</span></div>', className: 'marker-cluster' + c, iconSize: new L.Point(40, 40) }});
        }}
        '''




def create_cluster(df : pd.DataFrame, fuel : str) -> MarkerCluster:
    
    mean_value = df[fuel].mean()
    std_dev = df[fuel].std()

    print(f"Mean value of {fuel} is {mean_value}")
    def get_color(z_score):
        if z_score > 3:
            return 'black'
        if z_score < -3:
            return 'pink'
        return colormap(z_score)


    cluster_markers = MarkerCluster(icon_create_function=js_func,overlay=False,name=f"{fuel}: avg:{mean_value:.4f}", options={"disableClusteringAtZoom":AGGREGATE_UNTIL_ZOOM},show=False)
    for idx, row in df.iterrows():
        z_score = (row[fuel] - mean_value) / std_dev
        color = get_color(z_score)
        if(float(row['latitude']) == 0 or float(row['longitude']) == 0):
            print(f"Insertin a 0 coordinate {row['station_uuid']}")
            continue

        marker = folium.CircleMarker(
            location=[row['latitude'], row['longitude']],
            tooltip=row['name'],
            fill=True,
            fill_opacity=1,
            opacity=1,
            fill_color=color,
            color=color,
            radius=2,
            popup=f"{fuel.capitalize()}: {row[fuel]:.4f}\nid:{row['station_uuid']}\npost_code:({row['post_code']})"
        )
        marker.options['z_score'] = z_score
        cluster_markers.add_child(marker)

    return cluster_markers



# plot a datafame
def map_analysis():

    m = folium.Map(tiles=None,location=(51.1657, 10.4515),zoom_start=7,control_scale=True)
    
    folium.TileLayer("CartoDB Positron",control=False).add_to(m)
    colormap.add_to(m)

    for fuel in ["diesel", "e5", "e10"]:
        df = query_closest_price(fuel)
        #df = df.head(4)
        print(f"Query done for {fuel}")

        #sanity check
        required_columns = ['station_uuid','name','post_code','latitude', 'longitude',fuel]
        assert set(required_columns).issubset(df.columns), f"Missing columns: {set(required_columns) - set(df.columns)}"

        plot_hg(df,fuel)
        print(f"Histogram ready for {fuel}")

        fuel_cluster = create_cluster(df,fuel)
        if fuel == "diesel":
            fuel_cluster.show = True

        fuel_cluster.add_to(m) 
        print(f"Cluster ready for {fuel}")
    
    folium.LayerControl().add_to(m)
    print("Plotting done")

    
    m.save(os.path.join(OUTPUT_FOLDER,"fuel_prices_germany.html"))
    print(f"Map saved in fuel_prices_germany.html")


def main():    
    os.makedirs(OUTPUT_FOLDER, exist_ok=True)
    map_analysis()

if __name__ == "__main__":
    main()