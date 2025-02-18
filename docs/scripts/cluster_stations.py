from common import *
import argparse

#plotting
import folium, random


DO_PLOT = True

OUTPUT_PARTIAL="stations_clusters_partial.html"
QUERY_PARTIAL="../sql/clustering/PartialCluster.sql"

OUTPUT_COMPLETE="stations_clusters.html"
QUERY_COMPLETE="../sql/clustering/ClusterStations.sql"

TABLE="stations_clusters"


GET_CLUSTERS_SQL=f"""
    SELECT id as station_id, city, latitude, longitude, cluster_name
    FROM {TABLE}, stations
    WHERE station_id = id
    """


def plot(output_file : str):
    generated_colors = set()
    def generate_color() -> str:
        while True:
            color = "#{:06x}".format(random.randint(0, 0xFFFFFF))
            if color not in generated_colors:
                generated_colors.add(color)
                return color


    city_to_color : dict[str, str] = {}
    def get_city_color(city : str) -> str:
        if city not in city_to_color:
            city_to_color[city] = generate_color()
        return city_to_color[city]
    
    
    df = run_query(GET_CLUSTERS_SQL)
    print(f"Query done | Available columns: {df.columns}")

    m = folium.Map(tiles=None,location=(51.1657, 10.4515),zoom_start=7,control_scale=True)
    folium.TileLayer("CartoDB Positron",control=False).add_to(m)

    for idx, row in df.iterrows():
        color = get_city_color(row['cluster_name'])
        marker = folium.CircleMarker(
            location=[row['latitude'], row['longitude']],
            tooltip=row['cluster_name'],
            fill=True,
            fill_opacity=1,
            opacity=1,
            fill_color=color,
            color=color,
            radius=2,
            popup=f"id:{row['station_id']}\ncity:{row['city']})"
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
    parser.add_argument('-p', '--partial', action='store_true', help='Run partial clustering')
    args = parser.parse_args()

    os.makedirs(OUTPUT_FOLDER, exist_ok=True)

    query_file = QUERY_PARTIAL if args.partial else QUERY_COMPLETE
    print(f"Executing: {query_file}")
    execute_statement(read_query(query_file))

    if DO_PLOT:
        plot_file = OUTPUT_PARTIAL if args.partial else OUTPUT_COMPLETE
        plot(plot_file)
    
    if args.export:
        export_clusters(args.export)
        print(f"Clusters exported to {args.export}")


main()
 

