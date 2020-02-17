# GIS

Geographic Information System files for Massachusetts.

- shp - Original shapefiles from [Mass GIS](https://docs.digital.mass.gov/dataset/massgis-data-layers)
- geojson - GeoJSON versions, converted from shp directory

```
ogr2ogr -f GeoJSON -t_srs crs:84 geojson/towns2019.geojson shp/towns2019/TOWNSSURVEY_POLYM.shp
ogr2ogr -f GeoJSON -t_srs crs:84 geojson/counties.geojson shp/counties/COUNTIESSURVEY_POLYM.shp
ogr2ogr -f GeoJSON -t_srs crs:84 geojson/house2012.geojson shp/house2012/HOUSE2012_POLY.shp
ogr2ogr -f GeoJSON -t_srs crs:84 geojson/senate2012.geojson shp/senate2012/SENATE2012_POLY.shp
```
