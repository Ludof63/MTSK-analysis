from common import *

#plotting
import folium
import branca.colormap as cm
from folium.plugins import MarkerCluster


OUTPUT_FILENAME="prices_on_map.html"
VALUE_COL="price"

TIME = '2024-11-01 12:00'
PARAMS ={'time' : TIME}

GRANULARITY_COLOR_AGGREGATE=10
AGGREGATE_UNTIL_ZOOM = 9
FUELS_TO_PLOT= ['diesel', 'e5']


COLORMAP = cm.LinearColormap(colors=['green', 'yellow', 'red'], vmin=-3, vmax=3)
COLORMAP.caption = f"Deviation from mean"


#custom clustering for points on map
step_cm = COLORMAP.to_step(GRANULARITY_COLOR_AGGREGATE)
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


def get_color(z_score):
        if z_score > 3:
            return 'black'
        if z_score < -3:
            return 'pink'
        return COLORMAP(z_score)

# Query prices for a certain fuel and create a markerCluster out of them
def create_cluster(fuel : str) -> MarkerCluster:
    df = query_priceat(fuel,False,PARAMS)
    print(f"Query done for {fuel}")

    mean_value, std_dev = df[VALUE_COL].mean(),df[VALUE_COL].std()
    print(f"Fuel: {fuel} -> Mean: {mean_value} | StdDev: {std_dev}")

    cluster_markers = MarkerCluster(icon_create_function=js_func,overlay=False,name=f"{fuel}: avg:{mean_value:.4f}", options={"disableClusteringAtZoom":AGGREGATE_UNTIL_ZOOM},show=False)
    for idx, row in df.iterrows():
        color = get_color(row['z_score'])

        marker = folium.CircleMarker(
            location=[row['latitude'], row['longitude']],
            tooltip=row[VALUE_COL],
            fill=True,
            fill_opacity=1,
            opacity=1,
            fill_color=color,
            color=color,
            radius=2,
            popup=f"id:{row['station_id']}\nval:{row[VALUE_COL]}\ncity:{row['city']}\nbrand:{row['brand']})"
        )
        marker.options['z_score'] = row['z_score']
        cluster_markers.add_child(marker)

    return cluster_markers



# For each fuel, query, create a MarkerCluster, add it to map
def map_analysis():
    m = folium.Map(tiles=None,location=(51.1657, 10.4515),zoom_start=7,control_scale=True)
    folium.TileLayer("CartoDB Positron",control=False).add_to(m)
    COLORMAP.add_to(m)

    for idx,fuel in enumerate(FUELS_TO_PLOT):
        fuel_cluster = create_cluster(fuel)
        if idx == 0:
            fuel_cluster.show = True

        fuel_cluster.add_to(m) 
        print(f"Added {fuel} cluster to the Map")
    
    folium.LayerControl().add_to(m)
    print("Plotting done")

    m.save(os.path.join(OUTPUT_FOLDER,OUTPUT_FILENAME)) #this takes a while!
    print(f"Map saved in {OUTPUT_FILENAME}")


def main():    
    os.makedirs(OUTPUT_FOLDER, exist_ok=True)
    map_analysis()

if __name__ == "__main__":
    main()