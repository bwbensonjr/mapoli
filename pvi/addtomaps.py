import pandas as pd
import geopandas as gpd
import electionstats

def main():
    sr_geom = gpd.read_file("../gis/geojson/house2012.geojson")
    sr_pvi = pd.read_csv("ma_state_rep_dist_pvi_2016.csv")
    sr_geom_pvi = pd.merge(sr_geom, sr_pvi.rename(columns={"State Rep": "REP_DIST"}), on="REP_DIST")
    sr_geom_pvi.to_file("../gis/geojson/house2012.geojson", driver="GeoJSON")

    ss_geom = gpd.read_file("../gis/geojson/senate2012.geojson")
    ss_geom["DISTRICT"] = ss_geom["SEN_DIST"].map(electionstats.word_to_number)
    ss_pvi = pd.read_csv("ma_state_senate_dist_pvi_2016.csv")
    ss_geom_pvi = pd.merge(ss_geom, ss_pvi.rename(columns={"State Senate": "DISTRICT"}), on="DISTRICT")
    ss_geom_pvi.to_file("../gis/geojson/senate2012.geojson", driver="GeoJSON")
    
