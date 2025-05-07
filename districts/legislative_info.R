library(tidyverse)
library(gt)
library(sf)
library(tmap)

pvi_all <-
    read_csv("../pvi/ma_legislative_district_pvi_2024.csv") |>
    mutate(district = str_replace(district, " & ", " and "))

legislative_offices <- unique(pvi_all$office)

leg_elections <-
    read_csv(
        str_c("https://bwbensonjr.github.io/",
              "ma-election-db/data/",
              "ma_general_election_summaries.csv.gz")
    ) |>
    filter(office %in% legislative_offices)

most_recent_general <-
    leg_elections |>
        filter(! is_special) |>
        group_by(office) |>
        arrange(desc(election_date)) |>
        slice(1) |>
        select(office, latest_general=election_date) |>
        ungroup()

latest_district_elections <-
    leg_elections |>
        left_join(most_recent_general, by="office") |>
        filter(election_date >= latest_general) |>
        group_by(office_id, district_id) |>
        arrange(desc(election_date)) |>
        slice(1) |>
        ungroup()

latest_district_elections |>
    write_csv("ma_latest_legislative_elections.csv")

legislative_district_info <-
    latest_district_elections |>
        mutate(district = str_replace(district, " & ", " and ")) |>
        select(
            office,
            district_id,
            district,
            legislator=display_winner,
            party=party_winner,
            city_town=city_town_winner,
            percent=percent_winner
        ) |>
        left_join(pvi_all, by=c("office", "district"))

legislative_district_info |>
    write_csv("ma_legislative_district_info.csv")

## Create HTML info tables by legislative office

district_table <- function(office_name) {
    legislative_district_info |>
        filter(office == office_name) |>
        arrange(district_id) |>
        gt() |>
        tab_header(
            title=md(str_glue("Massachusetts **{office_name}** Districts"))
        ) |>
        cols_hide(columns=c(office, district_id)) |>
        fmt_percent(columns=percent, decimals=0) |>
        fmt_number(columns=PVI_N, decimals=1) |>
        cols_width(
            c(percent, PVI, PVI_N) ~ px(100),
            party ~ px(170),
            city_town ~ px(200)
        ) |>
        opt_interactive(
            use_pagination=FALSE,
            use_search=TRUE,
            use_filters=TRUE,
            use_compact_mode=TRUE
        )
}

write_district_info_page <- function(office_name, output_file) {
    table <- district_table(office_name)
    gtsave(table, output_file)
}

write_district_info_page("State Representative", "state-rep/state-rep-districts.html")
write_district_info_page("State Senate", "state-senate/state-senate-districts.html")
write_district_info_page("Governor's Council", "gov-council/gov-council-districts.html")
write_district_info_page("U.S. House", "us-house/us-house-districts.html")

## Create map by legislative office

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
     tm_layout(title) +
     tm_basemap("OpenStreetMap"))
}

state_rep <- read_sf("../gis/geojson/house2021.geojson") |>
    mutate(office = "State Representative") |>
    left_join(legislative_district_info, by=c("office", "district")) |>
    select(-c(district_num, shape_area, office))

state_rep_map <- district_map(
    state_rep,
    "Massachusetts State Representative Districts",
    0.8
)              
tmap_save(state_rep_map, "state-rep/state-rep-map.html")

state_senate <- read_sf("../gis/geojson/senate2021.geojson") |>
    mutate(office = "State Senate") |>
    left_join(legislative_district_info, by=c("office", "district")) |>
    select(-c(district_num, shape_area, office))

state_senate_map <- district_map(
    state_senate,
    "Massachusetts State Senate Districts",
    0.9
)              
tmap_save(state_senate_map, "state-senate/state-senate-map.html")

gov_council <- read_sf("../gis/geojson/govcouncil2021.geojson") |>
    mutate(office = "Governor's Council") |>
    left_join(legislative_district_info, by=c("office", "district")) |>
    select(-c(district_num, shape_area, office))

gov_council_map <- district_map(
    gov_council,
    "Massachusetts Governor's Council Districts",
    1.5
)              
tmap_save(gov_council_map, "gov-council/gov-council-map.html")

us_house <- read_sf("../gis/geojson/congressma118.geojson") |>
    mutate(office = "U.S. House",
           district = as.character(district_num)) |>
    left_join(legislative_district_info, by=c("office", "district")) |>
    select(-c(district_num, shape_area, office))

us_house_map <- district_map(
    us_house,
    "Massachusetts U.S. House Districts",
    1.5
)              
tmap_save(us_house_map, "us-house/us-house-map.html")

# district_map <- (
#     state_rep_map +
#     state_senate_map +
#     gov_council_map +
#     us_house_map
# )
