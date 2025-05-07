library(tidyverse)
library(sf)
library(tmap)

ma_most_recent <- read_csv("https://bwbensonjr.github.io/ma-election-db/data/ma_general_election_summaries.csv.gz") |>
    filter(election_date >= "2024-11-05")

tmap_mode("view")

district_map <- function(dist, title, scale) {
    (tm_shape(dist, name=title) +
     tm_polygons(
         col="MAP_COLORS",
         alpha=0.6,
         popup.vars=c("legislator", "PVI")
     ) +
     tm_text(
         "district_display",
         size="AREA",
         scale=scale,
         fontfamily="serif",
         fontface="bold"
     ) +
     tm_view(text.size.variable=TRUE) +
     # tm_layout(title) +
     tm_basemap("OpenStreetMap"))
}

state_rep_names <- ma_most_recent |>
    filter(office == "State Representative") |>
    select(district, legislator=display_winner)

state_rep_pvi <- read_csv("../pvi/ma_state_rep_pres_pvi_2024.csv") |>
    select(district = State_Rep, PVI)

state_rep <- read_sf("../gis/geojson/house2021.geojson") |>
    select(-c(district_num, shape_area)) |>
    left_join(state_rep_names, by="district") |>
    left_join(state_rep_pvi, by="district")

state_rep_map <- district_map(
    state_rep,
    "Massachusetts State Representative Districts",
    0.8
)              
# tmap_save(state_rep_map, "ma_state_rep_districts.html")

state_senate_names <- ma_most_recent |>
    filter(office == "State Senate") |>
    select(district, legislator=display_winner) |>
    mutate(district = str_replace(district, " & ", " and "))

state_senate_pvi <- read_csv("../pvi/ma_state_senate_pres_pvi_2024.csv") |>
    select(district = State_Senate, PVI) |>
    mutate(district = str_replace(district, " & ", " and "))

state_senate <- read_sf("../gis/geojson/senate2021.geojson") |>
    select(-c(district_num, shape_area)) |>
    left_join(state_senate_names, by="district") |>
    left_join(state_senate_pvi, by="district")

state_senate_map <- district_map(
    state_senate,
    "Massachusetts State Senate Districts",
    0.9
)              
# tmap_save(state_senate_map, "ma_state_senate_districts.html")

gov_council_names <- ma_most_recent |>
    filter(office == "Governor's Council") |>
    select(district, legislator=display_winner)

gov_council_pvi <- read_csv("../pvi/ma_gov_council_pres_pvi_2024.csv") |>
    select(district = Gov_Council, PVI)

gov_council <- read_sf("../gis/geojson/govcouncil2021.geojson") |>
    select(-c(district_num, shape_area)) |>
    left_join(gov_council_names, by="district") |>
    left_join(gov_council_pvi, by="district")

gov_council_map <- district_map(
    gov_council,
    "Massachusetts Governor's Council Districts",
    1.5
)              
# tmap_save(gov_council_map, "ma_gov_council_districts.html")

us_house_names <- ma_most_recent |>
    filter(office == "U.S. House") |>
    select(district_num=district, legislator=display_winner) |>
    mutate(district_num = as.integer(district_num))

us_house_pvi <- read_csv("../pvi/ma_us_house_pres_pvi_2024.csv") |>
    select(district_num = US_House, PVI)

us_house <- read_sf("../gis/geojson/congressma118.geojson") |>
    select(-c(district_display, shape_area)) |>
    left_join(us_house_names, by="district_num") |>
    left_join(us_house_pvi, by="district_num") |>
    rename(district_display = district)

us_house_map <- district_map(
    us_house,
    "Massachusetts U.S. House Districts",
    1.5
)              
# tmap_save(us_house_map, "ma_us_house_districts.html")

district_map <- (
    state_rep_map +
    state_senate_map +
    gov_council_map +
    us_house_map
)
