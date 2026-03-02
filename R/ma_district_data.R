# R/ma_district_data.R
# Data loading functions for Massachusetts legislative district data
#
# These functions load and return data frames without side effects.
# Use these to access district, election, PVI, and demographic data.

library(tidyverse)
library(sf)
library(here)

# Source dependencies
source(here("R/district_utils.R"))

# Data file paths
MA_ELECTION_DB_URL <- "https://bwbensonjr.github.io/ma-election-db/data/"

#' Load precinct-to-district mapping with presidential results
#' @return Data frame with precinct-level data including district assignments
load_precinct_districts <- function() {
    read_csv(here("pvi/ma_precincts_districts_pres_2024.csv"),
             show_col_types = FALSE) |>
        mutate(State_Senate = fix_district(State_Senate),
               US_House = fix_district(US_House))
}

#' Load district-level PVI data
#' @return Data frame with PVI for each legislative district
load_district_pvi <- function() {
    read_csv(here("pvi/ma_legislative_district_pvi_2024.csv"),
             show_col_types = FALSE) |>
        mutate(district = fix_district(district))
}

#' Load district summaries (text descriptions)
#' @return Data frame with office, district, and summary columns
load_district_summaries <- function() {
    read_csv(here("districts/ma_leg_dists_w_summary.csv"),
             show_col_types = FALSE) |>
        select(office, district, summary)
}

#' Load legislative election summaries from MA Election DB
#' @return Data frame with all legislative election results since 1990
load_legislative_elections <- function() {
    # Get list of valid legislative offices
    pvi <- load_district_pvi()
    legislative_offices <- unique(pvi$office)

    read_csv(
        str_c(MA_ELECTION_DB_URL, "ma_general_election_summaries.csv.gz"),
        show_col_types = FALSE
    ) |>
        select(-num_incumbents) |>
        filter(office %in% legislative_offices) |>
        mutate(district = fix_district(district))
}

#' Get the most recent general election date for each office
#' @param leg_elections Data frame from load_legislative_elections()
#' @return Data frame with office and latest_general date
get_most_recent_general <- function(leg_elections) {
    leg_elections |>
        filter(!is_special) |>
        group_by(office) |>
        arrange(desc(election_date)) |>
        slice(1) |>
        select(office, latest_general = election_date) |>
        ungroup()
}

#' Get the most recent election for each district
#' @param leg_elections Data frame from load_legislative_elections()
#' @return Data frame with the latest election result for each district
get_latest_district_elections <- function(leg_elections) {
    most_recent <- get_most_recent_general(leg_elections)

    leg_elections |>
        left_join(most_recent, by = "office") |>
        filter(election_date >= latest_general) |>
        group_by(office_id, district_id) |>
        arrange(desc(election_date)) |>
        slice(1) |>
        ungroup()
}

#' Build comprehensive district info by joining elections, PVI, and summaries
#' @param leg_elections Data frame from load_legislative_elections()
#' @param pvi_all Data frame from load_district_pvi()
#' @param district_summaries Data frame from load_district_summaries()
#' @return Data frame with comprehensive info for each legislative district
build_district_info <- function(leg_elections = NULL,
                                pvi_all = NULL,
                                district_summaries = NULL) {
    # Load data if not provided
    if (is.null(leg_elections)) leg_elections <- load_legislative_elections()
    if (is.null(pvi_all)) pvi_all <- load_district_pvi()
    if (is.null(district_summaries)) district_summaries <- load_district_summaries()

    latest_elections <- get_latest_district_elections(leg_elections)

    latest_elections |>
        select(
            office,
            district_id,
            district,
            district_display,
            legislator = display_winner,
            party = party_winner,
            city_town = city_town_winner,
            percent = percent_winner
        ) |>
        left_join(pvi_all, by = c("office", "district")) |>
        left_join(district_summaries, by = c("office", "district"))
}

#' Load all district data in one call (convenience function)
#' @return Named list with prec_dist, pvi, elections, and district_info
load_all_district_data <- function() {
    prec_dist <- load_precinct_districts()
    pvi <- load_district_pvi()
    elections <- load_legislative_elections()
    summaries <- load_district_summaries()
    district_info <- build_district_info(elections, pvi, summaries)

    list(
        prec_dist = prec_dist,
        pvi = pvi,
        elections = elections,
        summaries = summaries,
        district_info = district_info
    )
}

# --- Demographics Data ---

#' Get the demographics file path for an office
#' @param office_name Office name (e.g., "State Representative")
#' @return File path to demographics CSV
office_demographics_file <- function(office_name) {
    case_when(
        (office_name == "State Representative") ~ here("demographics/data/ma_state_rep_demographics.csv"),
        (office_name == "State Senate") ~ here("demographics/data/ma_state_senate_demographics.csv"),
        (office_name == "Governor's Council") ~ here("demographics/data/ma_gov_council_demographics.csv"),
        (office_name == "U.S. House") ~ here("demographics/data/ma_us_house_demographics.csv")
    )
}

#' Load demographics data for an office
#' @param office_name Office name (e.g., "State Representative")
#' @return Data frame with demographic variables for each district
load_office_demographics <- function(office_name) {
    read_csv(office_demographics_file(office_name), show_col_types = FALSE) |>
        mutate(area_sq_miles = area_m2 / 2.58999e6)
}

#' Load demographics for a specific district
#' @param office_name Office name
#' @param district_name District name
#' @return Single-row data frame with demographic data
load_district_demographics <- function(office_name, district_name) {
    load_office_demographics(office_name) |>
        filter(district == district_name)
}

# --- Geometry Data ---

#' Get the geometry file path for an office
#' @param office_name Office name
#' @return File path to GeoJSON file
office_geometry_file <- function(office_name) {
    case_when(
        (office_name == "State Representative") ~ here("gis/geojson/house2021.geojson"),
        (office_name == "State Senate") ~ here("gis/geojson/senate2021.geojson"),
        (office_name == "Governor's Council") ~ here("gis/geojson/govcouncil2021.geojson"),
        (office_name == "U.S. House") ~ here("gis/geojson/congressma118.geojson")
    )
}

#' Load district geometry for an office
#' @param office_name Office name
#' @return sf object with district boundaries
load_office_geometry <- function(office_name) {
    read_sf(office_geometry_file(office_name))
}

#' Load precinct geometry
#' @return sf object with precinct boundaries
load_precinct_geometry <- function(with_subs=TRUE) {
    if (with_subs) {
        read_sf(here("gis/geojson/wards_pcts_subs_2022.geojson")) |>
            select(city_town, ward = Ward, precinct = Pct, geometry)
    } else {
        read_sf(here("gis/geojson/wardsprecincts2022.geojson")) |>
            select(city_town, ward, precinct, geometry)
    }
}
