import folium
import geopandas as gpd

def main():
    state_rep = (
        gpd.read_file("../gis/geojson/house2021.geojson")
        .set_crs("EPSG:4326", inplace=False, allow_override=True)
    )
    m = folium.Map(location=[42.4072, -71.3824], zoom_start=8)
    # Define a style function for transparent fill
    def style_function(feature):
        return {
            'fillColor': '#3186cc',      # Blue fill
            'color': 'black',            # Border color
            'weight': 1,                 # Border width
            'fillOpacity': 0.6           # Transparency (0 = transparent, 1 = opaque)
    }

    # Add the polygons to the map
    folium.GeoJson(
        state_rep,
        name="Legislative Districts",
        style_function=style_function,
        # tooltip=folium.GeoJsonTooltip(fields=state_rep.columns.tolist())  # optional: show attributes
    ).add_to(m)
    m.save("folium_state_rep.html")
