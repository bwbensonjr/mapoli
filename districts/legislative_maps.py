import hvplot.pandas
import pandas as pd
import geopandas as gpd
import panel as pn

def main():
    ma_most_recent = pd.read_csv(
        "https://bwbensonjr.github.io/ma-election-db/data/"
        "ma_general_election_summaries.csv.gz"
    )
    state_rep_names = (
        ma_most_recent
        .query("office == 'State Representative'")
        .rename(columns={"display_winner": "legislator"})
        [["district", "legislator"]]
    )
    state_rep_pvi = (
        pd.read_csv("../pvi/ma_state_rep_pres_pvi_2024.csv")
        .rename(columns={"State_Rep": "district"})
        [["district", "PVI"]]
    )
    state_rep = (
        gpd.read_file("../gis/geojson/house2021.geojson")
        .merge(state_rep_names, on=["district"], how="left")
        .merge(state_rep_pvi, on=["district"], how="left")
    )
    sr_plot = state_rep.hvplot(geo=True)
    pn.pane.HoloViews(sr_plot).show()


    gpd.read_file("../gis/shp/HOUSE2021/HOUSE2021_POLY.shp")

## Bokeh version (works in Jupyter notebook)

from bokeh.plotting import figure, show
from bokeh.models import WMTSTileSource
from bokeh.palettes import Category10
import geopandas as gpd
from bokeh.models import GeoJSONDataSource
import itertools

# Load and convert GeoJSON
gdf = gpd.read_file("../gis/geojson/house2021.geojson")
gdf = gdf.to_crs(epsg=3857)  # Required for tile overlay

colors = Category10[10]  # 10 distinct colors
gdf["color"] = list(itertools.islice(itertools.cycle(colors), len(gdf)))

# Convert to GeoJSONDataSource
geo_source = GeoJSONDataSource(geojson=gdf.to_json())
minx, miny, maxx, maxy = gdf.total_bounds

# Create figure in Web Mercator
p = figure(
    x_range=(minx, maxx),
    y_range=(miny, maxy),
    x_axis_type="mercator",
    y_axis_type="mercator",
    width=1000,
    height=700,
    title="Map with OpenStreetMap tiles"
)

# Add OpenStreetMap tile layer
tile_source = WMTSTileSource(url='https://c.tile.openstreetmap.org/{Z}/{X}/{Y}.png')
p.add_tile(tile_source)

# Hide axes and grid
p.axis.visible = False
p.grid.visible = False

# Add GeoJSON polygons
p.patches(
    "xs",
    "ys",
    source=geo_source,
    fill_color="color",
    fill_alpha=0.6,
    line_color="black",
    line_width=0.5,
)

show(p)
