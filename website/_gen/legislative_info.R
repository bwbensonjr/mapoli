# website/_gen/legislative_info.R
# Website-specific rendering functions for Massachusetts legislative district pages
#
# This file provides gt tables and tmap maps for the website.
# Data loading and query functions are in the shared R/ modules.

library(tidyverse)
library(gt)
library(sf)
library(tmap)
library(quarto)
library(here)
library(htmlwidgets)
library(webshot2)

# Reset here() to project root (here 1.0.2 detects _quarto.yml in website/)
here::i_am("website/_gen/legislative_info.R")

# Source shared modules
source(here("R/district_utils.R"))
source(here("R/precinct_utils.R"))
source(here("R/ma_district_data.R"))
source(here("R/ma_district_query.R"))

# --- Website URL Functions ---
# These must be defined before data loading since they're used in mutate()

#' Generate district page filename
district_file <- function(office_name, district_name) {
    str_glue("{district_slug(district_name)}.html")
}

#' Generate markdown link to district page
district_md_ref <- function(office_name, district_name) {
    str_glue("[{district_name}]({district_file(office_name, district_name)})")
}

#' Generate HTML link to district page (for map popups)
district_web_ref <- function(office_name, district_name) {
    str_glue("<a href={district_file(office_name, district_name)}>{district_name}</a>")
}

# --- Load Data ---
# Data is loaded once when this file is sourced

prec_dist <- load_precinct_districts()
pvi_all <- load_district_pvi()
leg_elections <- load_legislative_elections()
district_summaries <- load_district_summaries()
prec_demographics <- load_precinct_demographics()

# Build the main district info data frame
legislative_district_info <- build_district_info(leg_elections, pvi_all, district_summaries) |>
    mutate(
        district_md_ref = district_md_ref(office, district),
        district_web_ref = district_web_ref(office, district)
    )

# Derived data
legislative_offices <- unique(pvi_all$office)
city_town_num_precincts <- count_city_town_precincts(prec_dist)

# --- Query Wrapper Functions ---
# These wrap the shared query functions using the pre-loaded data

#' Get summary text for a district
district_summary <- function(office_name, district_name) {
    get_district_summary(legislative_district_info, office_name, district_name)
}

#' Get display name for a district
district_display_name <- function(office_name, district_name) {
    get_district_display_name(legislative_district_info, office_name, district_name)
}

#' Get incumbent legislator for a district
district_incumbent <- function(office_name, district_name) {
    get_district_incumbent(legislative_district_info, office_name, district_name)
}

#' Get demographics for an office (wrapper)
office_demographics <- function(office_name) {
    load_office_demographics(office_name) |>
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

#' Get precincts by city/town for an office
city_town_precincts <- function(office_name) {
    get_city_town_districts(prec_dist, office_name) |>
        left_join(
            legislative_district_info |>
                filter(office == office_name) |>
                select(district, legislator),
            by = "district"
        ) |>
        select(city_town, district, legislator, precincts)
}

# --- GT Table Functions ---

#' Political summary table for an office
office_table_political <- function(office_name) {
    legislative_district_info |>
        filter(office == office_name) |>
        arrange(district_id) |>
        select(district_md_ref, legislator, party, city_town, percent, PVI, PVI_N) |>
        gt() |>
        cols_label(
            district_md_ref = "District",
            legislator = "Legislator",
            party = "Party",
            city_town = "City/Town",
            percent = "Vote"
        ) |>
        fmt_markdown(columns = district_md_ref) |>
        fmt_percent(columns = percent, decimals = 0) |>
        fmt_number(columns = PVI_N, decimals = 1) |>
        cols_width(
            c(percent, PVI, PVI_N) ~ px(100),
            party ~ px(170),
            city_town ~ px(200)
        ) |>
        opt_interactive(
            use_pagination = FALSE,
            use_search = TRUE,
            use_filters = TRUE,
            use_compact_mode = TRUE
        )
}

#' Demographic summary table for an office
office_table_demographic <- function(office_name) {
    legislative_district_info |>
        filter(office == office_name) |>
        arrange(district_id) |>
        select(district, district_md_ref, legislator) |>
        left_join(office_demographics(office_name), by = "district") |>
        select(
            district_md_ref, legislator, area_sq_miles, density_type,
            below_poverty_pct, ed_college_degree_pct, wwc_pct,
            race_minority_pct, race_white_pct, race_black_pct,
            race_asian_pct, race_hispanic_pct
        ) |>
        gt() |>
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
        fmt_markdown(columns = district_md_ref) |>
        fmt_percent(columns = ends_with("_pct"), decimals = 0) |>
        fmt_number(columns = c(area_sq_miles), decimals = 0) |>
        cols_width(
            ends_with("_pct") ~ px(75),
            area_sq_miles ~ px(80),
            density_type ~ px(100),
            legislator ~ px(220),
            district_md_ref ~ px(200)
        ) |>
        opt_interactive(
            use_pagination = FALSE,
            use_search = TRUE,
            use_filters = TRUE,
            use_compact_mode = TRUE
        )
}

#' Simple office table (for districts index page)
simple_office_table <- function(office_name) {
    off_rep_slug <- str_c("(", office_slug(office_name), "/")
    legislative_district_info |>
        filter(office == office_name) |>
        # Hack to make the link work from the "districts" path level
        mutate(district_md_ref = str_replace(district_md_ref, fixed("("), fixed(off_rep_slug))) |>
        arrange(district_id) |>
        select(district_md_ref, legislator, party, city_town, percent, PVI, PVI_N) |>
        gt() |>
        cols_label(
            district_md_ref = "District",
            legislator = "Legislator",
            party = "Party",
            city_town = "City/Town",
            percent = "Vote"
        ) |>
        fmt_markdown(columns = district_md_ref) |>
        fmt_percent(columns = percent, decimals = 0) |>
        fmt_number(columns = PVI_N, decimals = 1) |>
        cols_width(
            c(percent, PVI, PVI_N) ~ px(100),
            party ~ px(170),
            city_town ~ px(200)
        )
}

#' Static HTML list of district links for an office (for SEO crawlability)
office_district_links <- function(office_name) {
    legislative_district_info |>
        filter(office == office_name) |>
        arrange(district_id) |>
        mutate(link = str_glue(
            '<a href="{district_file(office, district)}">{district}</a>'
        )) |>
        pull(link) |>
        str_c(collapse = " | ") |>
        cat()
}

#' Election history table for a district
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
        cols_hide(columns = display_winner) |>
        sub_missing(missing_text = "") |>
        fmt_percent(columns = starts_with("percent_"), decimals = 0) |>
        tab_spanner(label = "Democratic", columns = ends_with("_dem")) |>
        tab_spanner(label = "Republican", columns = ends_with("_gop")) |>
        tab_spanner(label = "Third-Party", columns = ends_with("_third_party")) |>
        cols_label(-election_date ~ "", election_date = "Date") |>
        cols_width(c(percent_dem, percent_gop, percent_third_party) ~ px(120)) |>
        tab_style(
            style = cell_text(weight = "bold"),
            locations = list(
                cells_body(columns = display_dem, rows = (display_dem == display_winner)),
                cells_body(columns = display_gop, rows = (display_gop == display_winner)),
                cells_body(columns = display_third_party, rows = (display_third_party == display_winner))
            )
        )
}

#' Precincts table for a district
district_precincts <- function(office_name, district_name) {
    get_district_precincts_by_city_town(prec_dist, office_name, district_name) |>
        gt() |>
        cols_label(
            city_town = "City/Town",
            precincts = "Precincts"
        )
}

#' Demographics table for a district
district_demographics <- function(office_name, district_name) {
    load_district_demographics(office_name, district_name) |>
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
            columns = vars(Value),
            rows = (Variable %in% c(
                "Below Poverty", "College Degree", "Minority",
                "White", "Black", "Asian", "Hispanic", "White Working-Class"
            )),
            decimals = 0
        ) |>
        fmt_number(
            columns = vars(Value),
            rows = (Variable %in% c("Population", "Area (square miles)")),
            decimals = 0
        )
}

# --- tmap Functions ---

tmap_mode("view")
# Note: check.and.fix option removed - not supported in tmap v4
# Geometry validation is handled via st_make_valid() in query functions

#' Map scale factor for an office
office_map_scale <- function(office_name) {
    case_when(
        (office_name == "State Representative") ~ 0.8,
        (office_name == "State Senate") ~ 0.9,
        (office_name == "Governor's Council") ~ 1.5,
        (office_name == "U.S. House") ~ 1.5
    )
}

#' Statewide map for an office
office_map <- function(office_name) {
    title <- str_glue("Massachusetts {office_name} Districts")
    scale <- office_map_scale(office_name)
    office_df <- load_office_geometry(office_name) |>
        select(-district_display) |>
        mutate(office = office_name) |>
        left_join(legislative_district_info, by = c("office", "district")) |>
        left_join(office_demographics(office_name), by = "district")

    (tm_shape(office_df) +
        tm_polygons(
            col = "MAP_COLORS",
            alpha = 0.6,
            popup.vars = c(
                "legislator",
                "PVI",
                "Details" = "district_web_ref",
                "Area (mi^2)" = "area_sq_miles",
                "Density Type" = "density_type"
            ),
            popup.format = list(html.escape = FALSE)
        ) +
        tm_text(
            "district_display",
            clustering = leaflet::markerClusterOptions(
                maxClusterRadius = 40,
                disableClusteringAtZoom = 12
            )
        ) +
        tm_view(text.size.variable = TRUE) +
        tm_layout(title) +
        tm_basemap("OpenStreetMap"))
}

#' Map for a single district
district_map <- function(office_name, district_name, simp_tol = 50) {
    dist_geom <- get_district_geometry(
        load_precinct_geometry(),
        prec_dist,
        office_name,
        district_name
    ) |>
        st_buffer(dist = 10) |>
        st_buffer(dist = -10) |>
        st_simplify(dTolerance = 25)

    # Create centroids for municipality labels
    dist_centroids <- dist_geom |>
        st_centroid() |>
        select(label = city_town, geometry)

    (tm_shape(dist_geom) +
        tm_polygons(
            col = "MAP_COLORS",
            alpha = 0.6,
            popup.vars = c(
                "City/Town" = "city_town",
                "Precincts" = "label"
            )
        ) +
        tm_shape(dist_centroids) +
        tm_text("label") +
        tm_basemap("OpenStreetMap"))
}

#' Map showing overlap between a district and another office's districts
#' @param office_name Office of the primary district (e.g., "State Senate")
#' @param district_name Primary district name (e.g., "First Middlesex")
#' @param overlap_office Office to show overlaps with (e.g., "State Representative")
#' @return tmap object with interactive map
intersection_map <- function(office_name, district_name, overlap_office) {
    office_col <- office_column(office_name)
    overlap_col <- office_column(overlap_office)

    # Get precincts in the primary district with their overlap office assignments
    dist_prec <- prec_dist |>
        filter(!!sym(office_col) == district_name) |>
        select(city_town, ward, precinct, overlap_district = !!sym(overlap_col))

    if (nrow(dist_prec) == 0) {
        stop(str_glue("No precincts found for {office_name} district '{district_name}'"))
    }

    # Join with precinct geometry and demographics
    prec_geom <- load_precinct_geometry()

    dist_geom <- prec_geom |>
        right_join(dist_prec, by = c("city_town", "ward", "precinct")) |>
        left_join(
            prec_demographics |> select(city_town, ward, precinct, total_population),
            by = c("city_town", "ward", "precinct")
        ) |>
        filter(!st_is_empty(geometry)) |>
        st_make_valid()

    # Aggregate precincts by overlap district
    dist_agg <- dist_geom |>
        group_by(overlap_district) |>
        summarize(
            num_precincts = n(),
            population = sum(total_population, na.rm = TRUE),
            geometry = st_union(geometry),
            .groups = "drop"
        ) |>
        st_make_valid() |>
        st_buffer(dist = 10) |>
        st_buffer(dist = -10) |>
        st_simplify(dTolerance = 25) |>
        filter(!st_is_empty(geometry))

    # Join legislator information
    dist_agg <- dist_agg |>
        left_join(
            legislative_district_info |>
                filter(office == overlap_office) |>
                select(overlap_district = district, legislator),
            by = "overlap_district"
        )

    # Create centroids for labels
    dist_centroids <- dist_agg |>
        st_centroid() |>
        select(label = overlap_district, geometry)

    # Create the map with aggregated districts
    (tm_shape(dist_agg) +
        tm_polygons(
            fill = "overlap_district",
            fill.scale = tm_scale_categorical(value.na = NA),
            fill_alpha = 0.6,
            popup.vars = c(
                "District" = "overlap_district",
                "Legislator" = "legislator",
                "Precincts" = "num_precincts",
                "Intersecting Population" = "population"
            )
        ) +
        tm_shape(dist_centroids) +
        tm_text("label") +
        tm_basemap("OpenStreetMap"))
}

#' Save office map as PNG
save_office_map_image <- function(leaflet_map, office_name) {
    out_file <- here(
        "docs/districts",
        office_slug(office_name),
        "statewide-map.png"
    )
    temp_html <- tempfile(fileext = ".html")
    saveWidget(leaflet_map, temp_html, selfcontained = TRUE)
    webshot(
        temp_html,
        file = out_file,
        vwidth = 800,
        vheight = 600,
        cliprect = "viewport"
    )
}

#' Save district map as PNG
save_district_map_image <- function(leaflet_map, office_name, district_name) {
    out_file <- here(
        "docs/districts",
        office_slug(office_name),
        str_c(district_slug(district_name), ".png")
    )
    temp_html <- tempfile(fileext = ".html")
    saveWidget(leaflet_map, temp_html, selfcontained = TRUE)
    webshot(
        temp_html,
        file = out_file,
        vwidth = 800,
        vheight = 600,
        cliprect = "viewport"
    )
}
