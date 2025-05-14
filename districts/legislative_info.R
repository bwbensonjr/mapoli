library(tidyverse)
library(gt)
library(sf)
library(tmap)
library(quarto)

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

## Read district-level PVI data for joining with elections
##
pvi_all <-
    read_csv("../pvi/ma_legislative_district_pvi_2024.csv") |>
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

## Office-specific path
office_path <- function(office_name) {
    str_glue("pages/{office_slug(office_name)}-districts.html")
}

## District-specific file name
district_file <- function(office_name, district_name) {
    str_glue("{office_slug(office_name)}-{district_slug(district_name)}.html")
}

district_path <- function(office_name, district_name) {
    str_glue("pages/{district_file(office_name, district_name)}")
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
legislative_district_info <-
    latest_district_elections |>
        mutate(district_md_ref = district_md_ref(office, district),
               district_web_ref = district_web_ref(office, district)) |>
        select(
            office,
            district_id,
            district,
            district_md_ref,
            district_web_ref,
            legislator=display_winner,
            party=party_winner,
            city_town=city_town_winner,
            percent=percent_winner
        ) |>
        left_join(pvi_all, by=c("office", "district"))

## legislative_district_info |>
##     write_csv("ma_legislative_district_info.csv")

## Office-level summary table of districts

office_table <- function(office_name) {
    legislative_district_info |>
        filter(office == office_name) |>
        arrange(district_id) |>
        gt() |>
        tab_header(
            title=md(str_glue("Massachusetts **{office_name}** Districts"))
        ) |>
        cols_hide(columns=c(office, district_id, district, district_web_ref)) |>
        cols_label(
            district_md_ref ~ "District",
            legislator ~ "Legislator",
            party ~ "Party",
            city_town ~ "City/Town",
            percent ~ "Vote"
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

## Office-level map

tmap_mode("view")

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
        (office_name == "State Representative") ~ "../gis/geojson/house2021.geojson",
        (office_name == "State Senate") ~ "../gis/geojson/senate2021.geojson",
        (office_name == "Governor's Council") ~ "../gis/geojson/govcouncil2021.geojson",
        (office_name == "U.S. House") ~ "../gis/geojson/congressma118.geojson"
    )
}

office_map <- function(office_name) {
    title <- str_glue("Massachusetts {office_name} Districts")
    scale <- office_map_scale(office_name)
    office_df <-
        read_sf(office_map_geom_file(office_name)) |>
        mutate(office = office_name) |>
        left_join(legislative_district_info,
                  by=c("office", "district"))
    (tm_shape(office_df) +
     tm_polygons(
         col="MAP_COLORS",
         alpha=0.6,
         popup.vars=c(
             "legislator",
             "PVI",
             "district_web_ref"
         ),
         popup.format=list(html.escape=FALSE)
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

district_table <- function(office_name, district_name) {
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
        tab_header(
            title=md(str_glue("Massachusetts **{district_name}** {office_name} District"))
        ) |>
        cols_hide(columns=display_winner) |>
        sub_missing(missing_text="") |>
        fmt_percent(columns=starts_with("percent_"), decimals=0) |>
        tab_spanner(label="Democratic", columns=ends_with("_dem")) |>
        tab_spanner(label="Republican", columns=ends_with("_gop")) |>
        tab_spanner(label="Third-Party", columns=ends_with("_third_party")) |>
        cols_label(-election_date ~ "", election_date ~ "Date") |> # Hide most column names
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

district_map <- function(office_name, district_name) {
    str_glue("{office_name} - {district_name}")
}