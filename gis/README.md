# GIS

Geographic Information System files for Massachusetts.

- shp - Original shapefiles from [Mass GIS](https://docs.digital.mass.gov/dataset/massgis-data-layers)
- geojson - GeoJSON versions, converted from shp directory

```
ogr2ogr -f GeoJSON -t_srs crs:84 geojson/house2012.geojson shp/house2012/HOUSE2012_POLY.shp
```
