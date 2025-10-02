library(tidyverse)
library(here)
library(sf)
library(tmap)

boston_geo <-
    read_sf(here("gis/geojson/wardsprecincts2022.geojson")) |>
    filter(city_town == "Boston") |>
    select(city_town, ward, precinct)

boston_demos <-
    read_csv(here("demographics/data/ma_precinct_demographics.csv")) |>
    filter(city_town == "Boston")

boston_pcts <-
    boston_geo |>
    right_join(
        boston_demos,
        by = c("city_town", "ward", "precinct")
    ) |>
    filter(!st_is_empty(geometry))

(tm_shape(boston_pcts) +
    tm_polygons(
        col = "poverty_pct"
    ))

