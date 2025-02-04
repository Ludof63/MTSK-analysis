from common import *
import argparse

#plotting
import folium, random

DO_PARTIAL = False
DO_PLOT = True

OUTPUT_PARTIAL="stations_clusters_partial.html"
QUERY_PARTIAL="../sql/clustering/PartialCluster.sql"

OUTPUT_COMPLETE="stations_clusters.html"
QUERY_COMPLETE="../sql/clustering/ClusterStations.sql"

TABLE="stations_clusters"

LIST_CLUSTERS ="""
    SELECT cluster, COUNT(id) as n_stations, ARRAY_AGG(latitude) AS lats, ARRAY_AGG(longitude) AS lons,
    FROM {table}, stations WHERE station_id = id
    GROUP BY cluster ORDER BY n_stations DESC;
    """


def insert_create_table(q : str) -> str:
    return f"CREATE TABLE {TABLE} AS " + q

def insert_list_cluster(q : str) -> str:
    return q.replace("select * from clusters", LIST_CLUSTERS.format(table="clusters"))


def plot_clusters(output_file : str):
    df = run_query(transform_query(LIST_CLUSTERS.format(table=TABLE)))
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
    run_query(f"SELECT * from {TABLE};").to_csv(outfile,index=False)


def main():  
    parser = argparse.ArgumentParser(description="Parse an optional -e <file_path> argument.")
    parser.add_argument('-e', '--export',type=str, metavar='file_path', help='Export the <file_path> as csv (path relative to the caller)')
    args = parser.parse_args()

    os.makedirs(OUTPUT_FOLDER, exist_ok=True)

    execute_statement(f"DROP TABLE IF EXISTS {TABLE};")
    query_file = QUERY_PARTIAL if DO_PARTIAL else QUERY_COMPLETE
    execute_statement(read_query(query_file,[insert_create_table]))

    if DO_PLOT:
        plot_file = OUTPUT_PARTIAL if DO_PARTIAL else OUTPUT_COMPLETE
        plot_clusters(plot_file)
    
    if args.export:
        export_clusters(args.export)
        print(f"Clusters exported to {args.export}")


main()
 

