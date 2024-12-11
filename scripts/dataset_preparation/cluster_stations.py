import os
import random
import re

import psycopg as pg
import pandas as pd
import folium

def get_real_path(relative_path : str) -> str:
    script_dir = os.path.dirname(os.path.abspath(__file__))
    return os.path.join(script_dir, relative_path)


USER = 'client'
USER_PSWD = 'client'
DB = 'client'
PORT=5432
CONN_STR=f"host=localhost port={PORT} user={USER} password={USER_PSWD} dbname={DB}"

OUTPUT_FOLDER = get_real_path("plots")


CLUSTERS_TABLE="stations_clusters"


#------------------------------------------------------------------------------------
def create_cluster_table(km_dst : int):
    query = open(get_real_path("../sql/queries/cluster_stations.sql"),"r").read()
    query =  re.sub(r'\$\d+', '%s', query)

    with pg.connect(CONN_STR) as conn:
        conn.execute(f"DROP TABLE IF EXISTS {CLUSTERS_TABLE};")
        conn.execute(query,params=(km_dst,)) #type: ignore


def merge_clusters_center(dst_km : int):        
    query = open(get_real_path(f"../sql/queries/closest_clusters.sql"),"r").read()
    query =  re.sub(r'\$\d+', '%s', query)

    with pg.connect(CONN_STR) as conn:
        while True:
            res = conn.execute(query).fetchone() #type: ignore
            
            if not res:
                print("Empty res")
                return 
            
            leader_a, leader_b, distance = res

            print(f"Got {leader_b} into {leader_a}   ({distance})")
            if distance > dst_km:
                print(f"END")
                return
            
            label = f"{leader_a} , {leader_b}"
            update_query = f"UPDATE stations_clusters SET cluster = '{label}' WHERE cluster = '{leader_a}' OR cluster = '{leader_b}';"
            print(update_query)
            conn.execute(update_query) #type: ignore




#-----------------------------------------------------------
def plot_cluster_on_map(file : str):
    generated_colors = set()
    def generate_color():
        while True:
            color = "#{:06x}".format(random.randint(0, 0xFFFFFF))
            
            if color not in generated_colors:
                generated_colors.add(color)
                return color

    m = folium.Map(tiles=None,location=(51.1657, 10.4515),zoom_start=7,control_scale=True)
    folium.TileLayer("CartoDB Positron",control=False).add_to(m)

    with pg.connect(CONN_STR) as conn:
        df = pd.read_sql(open(get_real_path("../sql/queries/list_clusters.sql"),"r").read(),conn)


    for idx, row in df.iterrows():
            color=generate_color()
            for i in range(row['n_stations']):
                marker = folium.CircleMarker(
                    location=[row['lats'][i], row['lons'][i]],
                    tooltip=row['cluster'],
                    fill=True,
                    fill_opacity=1,
                    opacity=1,
                    fill_color=color,
                    color=color,
                    radius=2,
                )
                marker.add_to(m)

    print("Plotting done")
    m.save(os.path.join(OUTPUT_FOLDER,f"{file}.html"))
    print(f"Map saved in {file}.html")
    
def export_clusters():
    with pg.connect(CONN_STR) as conn:
        df = pd.read_sql(f"SELECT * from {CLUSTERS_TABLE};", conn)

    df.to_csv(get_real_path(f"../data/{CLUSTERS_TABLE}.csv"), index=False)

#-----------------------------------------------------------
def main():    
    DST_KM = 30
    DO_PLOT=False

    create_cluster_table(DST_KM)
    print("CREATED TABLE stations_clusters")
    if DO_PLOT:
        os.makedirs(OUTPUT_FOLDER, exist_ok=True)
        plot_cluster_on_map(f'clusters_germany_{DST_KM}')


    merge_clusters_center(2*DST_KM)
    print("MERGED CLOSED CLUSTERS in TABLE stations_clusters")
    if DO_PLOT:
        plot_cluster_on_map(f'clusters_germany_{DST_KM}_center')

    export_clusters()



if __name__ == "__main__":
    main()