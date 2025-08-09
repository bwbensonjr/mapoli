library(tidyverse)
library(gt)
library(sf)
library(tmap)
library(quarto)
library(here)

fix_district <- function(district_name) {
    str_replace_all(
        district_name,
        c(" & " = " and ",
          "10" = "Tenth",
          "11" = "Eleventh",
          "1" = "First",
          "2" = "Second",
          "3" = "Third",
          "4" = "Fourth",
          "5" = "Fifth",
          "6" = "Sixth",
          "7" = "Seventh",
          "8" = "Eighth",
          "9" = "Ninth")
    )
}

## Districts by precinct
##
prec_dist <-
    read_csv(here("pvi/ma_precincts_districts_pres_2024.csv")) |>
    mutate(State_Senate = fix_district(State_Senate),
           US_House = fix_district(US_House))

## Read district-level PVI data for joining with elections
##
pvi_all <-
    read_csv(here("pvi/ma_legislative_district_pvi_2024.csv")) |>
    mutate(district = fix_district(district))

## "State Representative"
## "State Senate"
## "Governor's Council"
## "U.S. House"
##
legislative_offices <- unique(pvi_all$office)

## General election summaries from 1990 filtered
## for just the legislative offices.
##
leg_elections <-
    read_csv(
        str_c("https://bwbensonjr.github.io/",
              "ma-election-db/data/",
              "ma_general_election_summaries.csv.gz")
    ) |>
    filter(office %in% legislative_offices) |>
    mutate(district = fix_district(district))

## The most recent general election date for each
## legislative office.
##
most_recent_general <-
    leg_elections |>
        filter(! is_special) |>
        group_by(office) |>
        arrange(desc(election_date)) |>
        slice(1) |>
        select(office, latest_general=election_date) |>
        ungroup()

## The most recent election for each legislative
## district which may be the most recent general,
## or a special election that has happened since.
##
latest_district_elections <-
    leg_elections |>
        left_join(most_recent_general, by="office") |>
        filter(election_date >= latest_general) |>
        group_by(office_id, district_id) |>
        arrange(desc(election_date)) |>
        slice(1) |>
        ungroup()

## latest_district_elections |>
##     write_csv("ma_latest_legislative_elections.csv")

## Office-specific slug for use in file names.
##
office_slug <- function(office_name) {
    case_when(
        (office_name == "State Representative") ~ "state-rep",
        (office_name == "State Senate") ~ "state-senate",
        (office_name == "Governor's Council") ~ "gov-council",
        (office_name == "U.S. House") ~ "us-house"
    )
}

## District-specific slug for use in file names.
##
district_slug <- function(district_name) {
    str_replace_all(
        str_to_lower(district_name),
        c(" " = "-",
          "&" = "and",
          "," = "",
          "1" = "first",
          "2" = "second",
          "3" = "third",
          "4" = "fourth",
          "5" = "fifth",
          "6" = "sixth",
          "7" = "seventh",
          "8" = "eighth",
          "9" = "ninth")
     )
}

## District-specific file name
district_file <- function(office_name, district_name) {
    str_glue("{district_slug(district_name)}.html")
}

## Markdown reference to district file
district_md_ref <- function(office_name, district_name) {
    str_glue("[{district_name}]({district_file(office_name, district_name)})")
}

## `href` reference to district file for map label
district_web_ref <- function(office_name, district_name) {
    str_glue("<a href={district_file(office_name, district_name)}>{district_name}</a>")
}

## A high-level summary of districts used in office-level table.
##
## legislative_district_info <-
##     latest_district_elections |>
##         mutate(district_md_ref = district_md_ref(office, district),
##                district_web_ref = district_web_ref(office, district)) |>
##         select(
##             office,
##             district_id,
##             district,
##             district_md_ref,
##             district_web_ref,
##             legislator=display_winner,
##             party=party_winner,
##             city_town=city_town_winner,
##             percent=percent_winner
##         ) |>
##         left_join(pvi_all, by=c("office", "district"))

## legislative_district_info |>
##     write_csv("ma_legislative_district_info.csv")

legislative_district_info <-
    read_csv(here("districts/ma_leg_dists_w_summary.csv"))

## Office-level political and demographic summary tables

office_table_political <- function(office_name) {
    legislative_district_info |>
        filter(office == office_name) |>
        arrange(district_id) |>
        gt() |>
        cols_hide(columns=c(office, district_id, district, district_web_ref)) |>
        cols_label(
            district_md_ref = "District",
            legislator = "Legislator",
            party = "Party",
            city_town = "City/Town",
            percent = "Vote"
        ) |>
        fmt_markdown(columns=district_md_ref) |>
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

office_demo_file <- function(office_name) {
    case_when(
        (office_name == "State Representative") ~ here("demographics/data/ma_state_rep_demographics.csv"),
        (office_name == "State Senate") ~ here("demographics/data/ma_state_senate_demographics.csv"),
        (office_name == "Governor's Council") ~ here("demographics/data/ma_gov_council_demographics.csv"),
        (office_name == "U.S. House") ~ here("demographics/data/ma_us_house_demographics.csv"),
    )
}

office_demographics <- function(office_name) {
    read_csv(office_demo_file(office_name)) |>
        mutate(area_sq_miles = area_m2 / 2.58999e6) |>
        select(
            district,
            area_sq_miles,
            density_type,
            below_poverty_pct,
            ed_college_degree_pct,
            wwc_pct,
            race_minority_pct,
            race_white_pct,
            race_black_pct,
            race_asian_pct,
            race_hispanic_pct
        )
}

office_table_demographic <- function(office_name) {
    legislative_district_info |>
        filter(office == office_name) |>
        arrange(district_id) |>
        select(district, district_md_ref, legislator) |>
        left_join(
            office_demographics(office_name),
            by=c("district")
        ) |>
        gt() |>
        cols_hide(columns=c(district)) |>
        cols_label(
            district_md_ref = "District",
            legislator = "Legislator",
            area_sq_miles = "Area (mi^2)",
            density_type = "Density",
            below_poverty_pct = "Poverty",
            ed_college_degree_pct = "College Degree",
            wwc_pct = "White Working-Class",
            race_minority_pct = "Minority",
            race_white_pct = "White",
            race_black_pct = "Black",
            race_asian_pct = "Asian",
            race_hispanic_pct = "Hispanic"
        ) |>
        fmt_markdown(columns=district_md_ref) |>
        fmt_percent(
            columns=ends_with("_pct"),
            decimals=0
        ) |>
        fmt_number(columns=c(area_sq_miles), decimals=0) |>
        cols_width(
            ends_with("_pct") ~ px(75),
            area_sq_miles ~ px(80),
            density_type ~ px(100),
            legislator ~ px(220),
            district_md_ref ~ px(200)
        ) |>
        opt_interactive(
            use_pagination=FALSE,
            use_search=TRUE,
            use_filters=TRUE,
            use_compact_mode=TRUE
        )
}

## Office-level map

tmap_mode("view")
tmap_options(check.and.fix=TRUE)

office_map_scale <- function(office_name) {
    case_when(
        (office_name == "State Representative") ~ 0.8,
        (office_name == "State Senate") ~ 0.9,
        (office_name == "Governor's Council") ~ 1.5,
        (office_name == "U.S. House") ~ 1.5
    )
}

office_map_geom_file <- function(office_name) {
    case_when(
        (office_name == "State Representative") ~ here("gis/geojson/house2021.geojson"),
        (office_name == "State Senate") ~ here("gis/geojson/senate2021.geojson"),
        (office_name == "Governor's Council") ~ here("gis/geojson/govcouncil2021.geojson"),
        (office_name == "U.S. House") ~ here("gis/geojson/congressma118.geojson")
    )
}

office_map <- function(office_name) {
    title <- str_glue("Massachusetts {office_name} Districts")
    scale <- office_map_scale(office_name)
    office_df <-
        read_sf(office_map_geom_file(office_name)) |>
        mutate(office = office_name) |>
        left_join(legislative_district_info,
                  by=c("office", "district")) |>
        left_join(office_demographics(office_name),
                  by=c("district"))
    (tm_shape(office_df) +
     tm_polygons(
         col="MAP_COLORS",
         alpha=0.6,
         popup.vars=c(
             "legislator",
             "PVI",
             "Details"="district_web_ref",
             "Area (mi^2)"="area_sq_miles",
             "Density Type"="density_type"
         ),
         popup.format=list(html.escape=FALSE)
     ) +
     tm_text(
         "district_display",
         clustering = leaflet::markerClusterOptions(
            maxClusterRadius = 40,    # smaller radius → more, tighter clusters
            disableClusteringAtZoom = 12   # stop clustering once zoom is ≥12
         )
         # clustering=TRUE
         # size="AREA",
         # scale=scale
     ) +
     tm_view(text.size.variable=TRUE) +
     tm_layout(title) +
     tm_basemap("OpenStreetMap"))
}

district_elections <- function(office_name, district_name) {
    leg_elections |>
        filter(office == office_name, district == district_name) |>
        mutate(special = if_else(is_special, "Special", "")) |>
        arrange(desc(election_date)) |>
        select(
            election_date,
            special,
            display_winner,
            display_dem,
            percent_dem,
            display_gop,
            percent_gop,
            display_third_party,
            percent_third_party
        ) |>
        gt() |>
        cols_hide(columns=display_winner) |>
        sub_missing(missing_text="") |>
        fmt_percent(columns=starts_with("percent_"), decimals=0) |>
        tab_spanner(label="Democratic", columns=ends_with("_dem")) |>
        tab_spanner(label="Republican", columns=ends_with("_gop")) |>
        tab_spanner(label="Third-Party", columns=ends_with("_third_party")) |>
        cols_label(-election_date ~ "", election_date = "Date") |> # Hide most column names
        cols_width(
            c(percent_dem, percent_gop, percent_third_party) ~ px(120)
        ) |>
        tab_style(
            style=cell_text(weight="bold"),
            locations=list(
                cells_body(columns=display_dem,
                           rows=(display_dem == display_winner)),
                cells_body(columns=display_gop,
                           rows=(display_gop == display_winner)),
                cells_body(columns=display_third_party,
                           rows=(display_third_party == display_winner))
            )
        )
}

office_column <- function(office_name) {
    case_when(
        (office_name == "State Representative") ~ "State_Rep",
        (office_name == "State Senate") ~ "State_Senate",
        (office_name == "Governor's Council") ~ "Gov_Council",
        (office_name == "U.S. House") ~ "US_House"
    )
}

city_town_total_precincts <-
    prec_dist |>
        group_by(city_town) |>
        summarize(total_precincts = n())

ward_precinct <- function(ward, precinct) {
    if_else(ward == "-",
            precinct,
            str_c(ward, "-", precinct))
}

district_precincts <- function(office_name, district_name) {
    office_col <- office_column(office_name)
    prec_dist |>
        filter(!!sym(office_col) == district_name) |>
        left_join(city_town_total_precincts, by="city_town") |>
        group_by(city_town) |>
        summarize(precincts = if_else((first(total_precincts) == n()),
                                      "-",
                                      str_flatten_comma(ward_precinct(ward, precinct)))) |>
        gt() |>
        cols_label(
            city_town = "City/Town",
            precincts = "Precincts"
        )
}

district_map <- function(office_name, district_name, simp_tol=50) {
    office_col <- office_column(office_name)
    dist_pcts <- prec_dist |>
        filter(!!sym(office_col) == district_name) |>
        left_join(city_town_total_precincts, by="city_town") |>
        select(city_town, ward, precinct, total_precincts)
    dist_geom <- read_sf(here("gis/geojson/wards_pcts_subs_2022.geojson")) |>
        select(city_town, ward=Ward, precinct=Pct, geometry) |>
        right_join(dist_pcts, by=c("city_town", "ward", "precinct")) |>
        filter(!st_is_empty(geometry)) |>
        group_by(city_town) |>
        summarize(name = if_else(
            first(total_precincts) == n(),
            first(city_town),
            str_glue("{first(city_town)} - {n()} of {first(total_precincts)} precincts")
            )
        ) |>
        st_make_valid() |>
        st_buffer(dist = 10) |>      # Small positive buffer
        st_buffer(dist = -10) |>     # Negative buffer to return to original size
        st_simplify(dTolerance = 25)
        ## st_simplify(dTolerance=simp_tol)
    (tm_shape(dist_geom) +
     tm_polygons(
         col="MAP_COLORS",
         alpha=0.6,
         popup.vars=c(
             "City/Town"="city_town",
             "Precincts"="name"
         )
     ) +
     tm_text("city_town") +
     tm_basemap("OpenStreetMap"))
}

district_demographics <- function(office_name, district_name) {
    read_csv(office_demo_file(office_name)) |>
        filter(district == district_name) |>
        mutate(area_sq_miles = area_m2 / 2.58999e6) |>
        select(
            Population = total_population,
            `Area (square miles)` = area_sq_miles,
            `Below Poverty` = below_poverty_pct,
            `College Degree` = ed_college_degree_pct,
            Minority = race_minority_pct,
            White = race_white_pct,
            Black = race_black_pct,
            Asian = race_asian_pct,
            Hispanic = race_hispanic_pct,
            `White Working-Class` = wwc_pct
        ) |>
        pivot_longer(
            cols = everything(),
            names_to = "Variable",
            values_to = "Value"
        ) |>
        gt() |>
        tab_options(column_labels.hidden = TRUE) |>
        fmt_percent(
            columns=vars(Value),
            rows=(Variable %in% c("Below Poverty",
                                        "College Degree",
                                        "Minority",
                                        "White",
                                        "Black",
                                        "Asian",
                                        "Hispanic",
                                        "White Working-Class")),
            decimals=0
        ) |>
        fmt_number(
            columns=vars(Value),
            rows=(Variable %in% c("Population",
                                  "Area (square miles)")),
            decimals=0
        )
}

simple_office_table <- function(office_name) {
    off_rep_slug <- str_c("(", office_slug(office_name), "/")
    legislative_district_info |>
        filter(office == office_name) |>
        ## Hack to make the link work from the "districts" path level
        mutate(district_md_ref = str_replace(district_md_ref, fixed("("), fixed(off_rep_slug))) |>
        arrange(district_id) |>
        gt() |>
        cols_hide(columns=c(office, district_id, district, district_web_ref)) |>
        cols_label(
            district_md_ref = "District",
            legislator = "Legislator",
            party = "Party",
            city_town = "City/Town",
            percent = "Vote"
        ) |>
        fmt_markdown(columns=district_md_ref) |>
        fmt_percent(columns=percent, decimals=0) |>
        fmt_number(columns=PVI_N, decimals=1) |>
        cols_width(
            c(percent, PVI, PVI_N) ~ px(100),
            party ~ px(170),
            city_town ~ px(200)
        )
}

district_summary <- function(office_name, district_name) {
    legislative_district_info |>
        filter(office == office_name,
               district == district_name) |>
        pull(summary)
}
