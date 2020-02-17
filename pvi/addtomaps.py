import pandas as pd
import geopandas as gpd
import electionstats

def main():
    # City/Town
    print("City/Town")
    ct_geom = gpd.read_file("../gis/geojson/towns2019.geojson")
    ct_geom["CITY_TOWN"] = ct_geom["TOWN"].map(lambda name:
                                               electionstats.abbreviate_compass(name.title())
                                               .replace("Manchester", "Manchester-by-the-Sea"))
    ct_pvi = pd.read_csv("ma_city_town_pvi_2016.csv")
    ct_geom_pvi = pd.merge(ct_geom, ct_pvi.rename(columns={"City/Town": "CITY_TOWN"}), on="CITY_TOWN")
    ct_geom_pvi.to_file("../gis/geojson/towns2019_pvi.geojson", driver="GeoJSON")

    # County
    print("County")
    county_geom = gpd.read_file("../gis/geojson/counties.geojson")
    county_geom["COUNTY_NAME"] = county_geom["COUNTY"].str.title()
    county_pvi = pd.read_csv("ma_county_pvi_2016.csv")
    county_geom_pvi = pd.merge(county_geom, county_pvi.rename(columns={"County": "COUNTY_NAME"}), on="COUNTY_NAME")
    county_geom_pvi.to_file("../gis/geojson/counties_pvi.geojson", driver="GeoJSON")
    
    # State Rep
    print("State Rep")
    sr_geom = gpd.read_file("../gis/geojson/house2012.geojson")
    sr_pvi = pd.read_csv("ma_state_rep_dist_pvi_2016.csv")
    sr_geom_pvi = pd.merge(sr_geom, sr_pvi.rename(columns={"State Rep": "REP_DIST"}), on="REP_DIST")
    sr_geom_pvi.to_file("../gis/geojson/house2012_pvi.geojson", driver="GeoJSON")

    # State Senate
    print("State Senate")
    ss_geom = gpd.read_file("../gis/geojson/senate2012.geojson")
    ss_geom["DISTRICT"] = ss_geom["SEN_DIST"].map(electionstats.word_to_number)
    ss_pvi = pd.read_csv("ma_state_senate_dist_pvi_2016.csv")
    ss_geom_pvi = pd.merge(ss_geom, ss_pvi.rename(columns={"State Senate": "DISTRICT"}), on="DISTRICT")
    ss_geom_pvi.to_file("../gis/geojson/senate2012_pvi.geojson", driver="GeoJSON")

    # US House
    print("US House")
    ush_geom = gpd.read_file("../gis/geojson/congress116th.geojson")
    ush_geom["CONG_DISTRICT"] = ush_geom["DISTRICT"].str[:-9]
    ush_pvi = pd.read_csv("ma_us_house_dist_pvi_2016.csv")
    ush_geom_pvi = pd.merge(ush_geom, ush_pvi.rename(columns={"US House": "CONG_DISTRICT"}), on="CONG_DISTRICT")
    ush_geom_pvi.to_file("../gis/geojson/congress116th_pvi.geojson", driver="GeoJSON")

    # Gov Council
    print("Gov Council")
    gc_geom = (gpd.read_file("../gis/geojson/govcouncil2012.geojson")
               .drop_duplicates(subset="DIST_NAME")) # For some reason there are duplicates
    gc_geom["GC_DIST"] = gc_geom["DIST_NAME"].map(electionstats.word_to_number)
    gc_pvi = pd.read_csv("ma_gov_council_dist_pvi_2016.csv")
    gc_geom_pvi = pd.merge(gc_geom, gc_pvi.rename(columns={"Gov Council": "GC_DIST"}), on="GC_DIST")
    gc_geom_pvi.to_file("../gis/geojson/govcouncil2012_pvi.geojson", driver="GeoJSON")

if __name__ == "__main__":
    main()
