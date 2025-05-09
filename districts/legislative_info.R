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
    filter(office %in% legislative_offices) |>
    mutate(district = str_replace(district, " & ", " and "))
    
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

office_prefix <- function(office_name) {
    case_when(
        (office_name == "State Representative") ~ "state-rep",
        (office_name == "State Senate") ~ "state-senate",
        (office_name == "Governor's Council") ~ "gov-council",
        (office_name == "U.S. House") ~ "us-house"
    )
}

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

district_file <- function(office_name, district_name) {
    str_glue("{office_prefix(office_name)}-{district_slug(district_name)}.html")
}

district_path <- function(office_name, district_name) {
    str_glue("pages/{district_file(office_name, district_name)}")
}

district_md_ref <- function(office_name, district_name) {
    str_glue("[{district_name}]({district_file(office_name, district_name)})")
}

district_web_ref <- function(office_name, district_name) {
    str_glue("<a href={district_file(office_name, district_name)}>{district_name}</a>")
}

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
        cols_hide(columns=c(office, district_id, district, district_web_ref)) |>
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

write_district_info_page <- function(office_name, output_file) {
    table <- district_table(office_name)
    gtsave(table, output_file)
}

write_district_info_page("State Representative", "pages/state-rep-districts.html")
write_district_info_page("State Senate", "pages/state-senate-districts.html")
write_district_info_page("Governor's Council", "pages/gov-council-districts.html")
write_district_info_page("U.S. House", "pages/us-house-districts.html")

## Create map by legislative office

tmap_mode("view")

district_map <- function(dist, title, scale) {
    (tm_shape(dist, name=title) +
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

state_rep <- read_sf("../gis/geojson/house2021.geojson") |>
    mutate(office = "State Representative") |>
    left_join(legislative_district_info, by=c("office", "district")) |>
    select(-c(district_num, shape_area, office))

state_rep_map <- district_map(
    state_rep,
    "Massachusetts State Representative Districts",
    0.8
)              
tmap_save(state_rep_map, "pages/state-rep-map.html")

state_senate <- read_sf("../gis/geojson/senate2021.geojson") |>
    mutate(office = "State Senate") |>
    left_join(legislative_district_info, by=c("office", "district")) |>
    select(-c(district_num, shape_area, office))

state_senate_map <- district_map(
    state_senate,
    "Massachusetts State Senate Districts",
    0.9
)              
tmap_save(state_senate_map, "pages/state-senate-map.html")

gov_council <- read_sf("../gis/geojson/govcouncil2021.geojson") |>
    mutate(office = "Governor's Council") |>
    left_join(legislative_district_info, by=c("office", "district")) |>
    select(-c(district_num, shape_area, office))

gov_council_map <- district_map(
    gov_council,
    "Massachusetts Governor's Council Districts",
    1.5
)              
tmap_save(gov_council_map, "pages/gov-council-map.html")

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
tmap_save(us_house_map, "pages/us-house-map.html")

# district_map <- (
#     state_rep_map +
#     state_senate_map +
#     gov_council_map +
#     us_house_map
# )

## Per-District Pages

election_history_table <- function(elections, office_name, district_name) {
    elections |>
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
        cols_label(-election_date ~ "") |> # Hide most column names
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

generate_district_page <- function(office_name, district_name) {
    table <- election_history_table(
        leg_elections,
        office_name,
        district_name
    )
    file_name <- district_path(office_name, district_name)
    gtsave(table, file_name)
}

legislative_district_info |>
    select(office, district) |>
    pwalk(generate_district_page)