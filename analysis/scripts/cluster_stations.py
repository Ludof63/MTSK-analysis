from common import *
import argparse

#plotting
import folium, random

DO_PLOT_CLUSTERS= False
OUTPUT_CLUSTERS="stations_clusters.html"

DO_PLOT_CLUSTERS_MERGED = False
OUTPUT_CLUSTERS_MERGED="stations_clusters_merged.html"


QUERY="../sql/clustering/ClusterStations.sql"
DST_THRESHOLD = 30
PARAMS ={'dst_threshold' : f'{DST_THRESHOLD}'}

TMP_TABLE="stations_clusters"

LIST_CLUSTERS ="""
SELECT 
    cluster, COUNT(id) as n_stations,
	ARRAY_AGG(latitude) AS lats, ARRAY_AGG(longitude) AS lons,
FROM {table}, stations WHERE station_id = id
GROUP BY cluster ORDER BY n_stations DESC;
"""

CLOSEST_CLUSTER = f"""
WITH clusters_centers AS (
    SELECT cluster, COUNT(id) as n_stations, AVG(latitude) AS lat, AVG(longitude) AS lon,
    FROM {TMP_TABLE}, stations WHERE station_id = id GROUP BY cluster
)
SELECT 
    tc1.cluster as leader_a,
    tc2.cluster as leader_b,
    (
        2 * 6371 * ATAN2(
            SQRT(
                POWER(SIN(RADIANS(tc1.lat - tc2.lat) / 2), 2) +
                COS(RADIANS(tc2.lat)) * COS(RADIANS(tc1.lat)) *
                POWER(SIN(RADIANS(tc1.lon - tc2.lon) / 2), 2)
            ),
            SQRT(1 - (
                POWER(SIN(RADIANS(tc1.lat - tc2.lat) / 2), 2) +
                COS(RADIANS(tc2.lat)) * COS(RADIANS(tc1.lat)) *
                POWER(SIN(RADIANS(tc1.lon - tc2.lon) / 2), 2)
            ))
        )
    ) as dst,
FROM  clusters_centers tc1, clusters_centers tc2
WHERE tc1.cluster <> tc2.cluster ORDER BY dst ASC LIMIT 1;


"""


def insert_create_table(q : str) -> str:
    return f"CREATE TABLE {TMP_TABLE} AS " + q

def insert_list_cluster(q : str) -> str:
    return q.replace("select * from clusters", LIST_CLUSTERS.format(table="clusters"))


def plot_clusters(output_file : str):
    df = run_query(transform_query(LIST_CLUSTERS.format(table=TMP_TABLE)))
    print(f"Query done | Available columns: {df.columns}")

    generated_colors = set()
    def generate_color():
        while True:
            color = "#{:06x}".format(random.randint(0, 0xFFFFFF))
            
            if color not in generated_colors:
                generated_colors.add(color)
                return color

    m = folium.Map(tiles=None,location=(51.1657, 10.4515),zoom_start=7,control_scale=True)
    folium.TileLayer("CartoDB Positron",control=False).add_to(m)

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
    m.save(os.path.join(OUTPUT_FOLDER,output_file))
    print(f"Map saved in {output_file}")

def export_clusters(outfile : str):
    run_query(f"SELECT * from {TMP_TABLE};").to_csv(outfile,index=False)

def main():  
    parser = argparse.ArgumentParser(description="Parse an optional -e <file_path> argument.")
    parser.add_argument('-e', '--export',type=str, metavar='file_path', help='Export the <file_path> as csv (path relative to the caller)')
    args = parser.parse_args()

    os.makedirs(OUTPUT_FOLDER, exist_ok=True)

    #create clusters
    execute_statement(f"DROP TABLE IF EXISTS {TMP_TABLE};")
    execute_statement(read_query(QUERY,[insert_create_table,insert_params_gen(PARAMS)]))
    
    if DO_PLOT_CLUSTERS:
        plot_clusters(OUTPUT_CLUSTERS)

    while True:
        res = run_query(CLOSEST_CLUSTER)
        assert not res.empty

        leader_a, leader_b, dst = res.loc[0]['leader_a'], res.loc[0]['leader_b'], res.loc[0]['dst']
        if dst > 2 * DST_THRESHOLD:
            print(f"END")
            break

        print(f"Merging {leader_b} into {leader_a}   ({dst})")
        execute_statement(f"UPDATE {TMP_TABLE} SET cluster = '{leader_a}, {leader_b}' WHERE cluster = '{leader_a}' OR cluster = '{leader_b}';")

    if DO_PLOT_CLUSTERS_MERGED:
        plot_clusters(OUTPUT_CLUSTERS_MERGED)
    
    if args.export:
        export_clusters(args.export)
        print(f"Clusters exported to {args.export}")


main()
 

