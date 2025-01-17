from common import *

#plotting
import folium, random

OUTPUT_FILENAME="cities_map.html"

QUERY="../sql/TopCitiesStations.sql"



def plot():
    generated_colors = set()
    def generate_color():
        while True:
            color = "#{:06x}".format(random.randint(0, 0xFFFFFF))
            
            if color not in generated_colors:
                generated_colors.add(color)
                return color
    
    df = run_query(QUERY)
    print(f"Query done | Available columns: {df.columns}")

    m = folium.Map(tiles=None,location=(51.1657, 10.4515),zoom_start=7,control_scale=True)
    folium.TileLayer("CartoDB Positron",control=False).add_to(m)

    for idx, row in df.iterrows():
            color=generate_color()
            for i in range(row['n_stations']):
                marker = folium.CircleMarker(
                    location=[row['lats'][i], row['lons'][i]],
                    tooltip=row['city'],
                    fill=True,
                    fill_opacity=1,
                    opacity=1,
                    fill_color=color,
                    color=color,
                    radius=2,
                )
                marker.add_to(m)

    print("Plotting done")
    m.save(os.path.join(OUTPUT_FOLDER,OUTPUT_FILENAME))
    print(f"Map saved in {OUTPUT_FILENAME}")


def main():  
    os.makedirs(OUTPUT_FOLDER, exist_ok=True)
    plot()

main()