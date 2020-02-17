#!/bin/sh
echo "City/Town"
ogr2ogr -f GeoJSON -t_srs crs:84 geojson/towns2019.geojson shp/towns2019/TOWNSSURVEY_POLYM.shp
echo "Counties"
ogr2ogr -f GeoJSON -t_srs crs:84 geojson/counties.geojson shp/counties/COUNTIESSURVEY_POLYM.shp
echo "State Rep"
ogr2ogr -f GeoJSON -t_srs crs:84 geojson/house2012.geojson shp/house2012/HOUSE2012_POLY.shp
echo "State Senate"
ogr2ogr -f GeoJSON -t_srs crs:84 geojson/senate2012.geojson shp/senate2012/SENATE2012_POLY.shp
echo "US House"
ogr2ogr -f GeoJSON -t_srs crs:84 geojson/congress116th.geojson shp/congress116th/CONGRESSMA_POLY.shp
echo "Gov Council"
ogr2ogr -f GeoJSON -t_srs crs:84 geojson/govcouncil2012.geojson shp/govcouncil2012/GOVCOUNCIL_POLY.shp
echo "Ward/Precincts"
ogr2ogr -f GeoJSON -t_srs crs:84 geojson/wardsprecincts2012.geojson shp/wardsprecincts2012/WARDSPRECINCTS_POLY.shp
