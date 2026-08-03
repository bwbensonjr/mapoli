# R/ma_district_query.R
# Query and lookup functions for Massachusetts legislative district data
#
# These functions take data frames as input and return filtered/computed results.
# They don't load data themselves - use ma_district_data.R for loading.

library(tidyverse)
library(sf)
library(here)

# Source dependencies
source(here("R/district_utils.R"))
source(here("R/precinct_utils.R"))

# --- District Info Queries ---

#' Get info for a specific district
#' @param district_info Data frame from build_district_info()
#' @param office_name Office name
#' @param district_name District name
#' @return Single-row data frame with district info
get_district_info <- function(district_info, office_name, district_name) {
    district_info |>
        filter(office == office_name, district == district_name)
}

#' Get the summary text for a district
#' @param district_info Data frame from build_district_info()
#' @param office_name Office name
#' @param district_name District name
#' @return Character string with district summary
get_district_summary <- function(district_info, office_name, district_name) {
    district_info |>
        filter(office == office_name, district == district_name) |>
        pull(summary)
}

#' Get the display name for a district
#' @param district_info Data frame from build_district_info()
#' @param office_name Office name
#' @param district_name District name
#' @return Character string with display name (e.g., "1st Bristol")
get_district_display_name <- function(district_info, office_name, district_name) {
    district_info |>
        filter(office == office_name, district == district_name) |>
        pull(district_display)
}

#' Get the incumbent legislator for a district
#' @param district_info Data frame from build_district_info()
#' @param office_name Office name
#' @param district_name District name
#' @return Character string with legislator name
get_district_incumbent <- function(district_info, office_name, district_name) {
    district_info |>
        filter(office == office_name, district == district_name) |>
        pull(legislator)
}

#' Get the PVI for a district
#' @param district_info Data frame from build_district_info()
#' @param office_name Office name
#' @param district_name District name
#' @return Character string with PVI (e.g., "D+15")
get_district_pvi <- function(district_info, office_name, district_name) {
    district_info |>
        filter(office == office_name, district == district_name) |>
        pull(PVI)
}

#' Get the numeric PVI for a district
#' @param district_info Data frame from build_district_info()
#' @param office_name Office name
#' @param district_name District name
#' @return Numeric PVI value
get_district_pvi_n <- function(district_info, office_name, district_name) {
    district_info |>
        filter(office == office_name, district == district_name) |>
        pull(PVI_N)
}

#' Get all districts for an office
#' @param district_info Data frame from build_district_info()
#' @param office_name Office name
#' @return Data frame with all districts for the office
get_office_districts <- function(district_info, office_name) {
    district_info |>
        filter(office == office_name) |>
        arrange(district_id)
}

# --- Election History Queries ---

#' Get election history for a district
#' @param leg_elections Data frame from load_legislative_elections()
#' @param office_name Office name
#' @param district_name District name
#' @return Data frame with election history, most recent first
get_district_election_history <- function(leg_elections, office_name, district_name) {
    leg_elections |>
        filter(office == office_name, district == district_name) |>
        arrange(desc(election_date))
}

#' Get the most recent election for a district
#' @param leg_elections Data frame from load_legislative_elections()
#' @param office_name Office name
#' @param district_name District name
#' @return Single-row data frame with most recent election
get_district_latest_election <- function(leg_elections, office_name, district_name) {
    get_district_election_history(leg_elections, office_name, district_name) |>
        slice(1)
}

# --- Primary Election Queries ---

#' Get contested primaries (more than one candidate of the same party)
#' @param primary_cands Data frame from load_primary_2026_candidates()
#' @return Data frame with office, district, district_id, party, num_candidates
get_contested_primaries <- function(primary_cands) {
    primary_cands |>
        count(office, district, district_id, party,
              name = "num_candidates") |>
        filter(num_candidates > 1) |>
        arrange(office, district_id, party)
}

#' Get districts with at least one contested primary for an office
#' @param primary_cands Data frame from load_primary_2026_candidates()
#' @param office_name Office name
#' @return Character vector of district names, in district_id order
get_contested_primary_districts <- function(primary_cands, office_name) {
    get_contested_primaries(primary_cands) |>
        filter(office == office_name) |>
        distinct(district, district_id) |>
        arrange(district_id) |>
        pull(district)
}

#' Get all primary candidates for a district, both parties
#'
#' Includes parties fielding a single candidate so an unopposed candidate
#' can be shown alongside a contested one in the same district.
#' @param primary_cands Data frame from load_primary_2026_candidates()
#' @param office_name Office name
#' @param district_name District name
#' @return Data frame with one row per candidate, Democrats first
get_district_primary_candidates <- function(primary_cands, office_name,
                                           district_name) {
    primary_cands |>
        filter(office == office_name, district == district_name) |>
        arrange(party, desc(is_incumbent), name)
}

# --- Precinct Queries ---

#' Count precincts per city/town
#' @param prec_dist Data frame from load_precinct_districts()
#' @return Data frame with city_town and num_precincts
count_city_town_precincts <- function(prec_dist) {
    prec_dist |>
        group_by(city_town) |>
        summarize(num_precincts = n(), .groups = "drop")
}

#' Get precincts for a specific district
#' @param prec_dist Data frame from load_precinct_districts()
#' @param office_name Office name
#' @param district_name District name
#' @return Data frame with city_town, ward, precinct for the district
get_district_precincts <- function(prec_dist, office_name, district_name) {
    office_col <- office_column(office_name)
    prec_dist |>
        filter(!!sym(office_col) == district_name) |>
        select(city_town, ward, precinct)
}

#' Get precincts by city/town for a district, summarized
#' @param prec_dist Data frame from load_precinct_districts()
#' @param office_name Office name
#' @param district_name District name
#' @return Data frame with city_town and precincts (comma-separated or "-" for all)
get_district_precincts_by_city_town <- function(prec_dist, office_name, district_name) {
    office_col <- office_column(office_name)
    city_town_counts <- count_city_town_precincts(prec_dist)

    prec_dist |>
        filter(!!sym(office_col) == district_name) |>
        left_join(city_town_counts, by = "city_town") |>
        group_by(city_town) |>
        summarize(
            precincts = if_else(
                first(num_precincts) == n(),
                "-",
                str_flatten_comma(ward_precinct(ward, precinct))
            ),
            .groups = "drop"
        )
}

#' Get city/towns with their districts for an office
#' @param prec_dist Data frame from load_precinct_districts()
#' @param office_name Office name
#' @return Data frame with city_town, district, and precincts
get_city_town_districts <- function(prec_dist, office_name) {
    office_col <- office_column(office_name)
    city_town_counts <- count_city_town_precincts(prec_dist)

    prec_dist |>
        left_join(city_town_counts, by = "city_town") |>
        rename(district = !!sym(office_col)) |>
        group_by(city_town, district) |>
        summarize(
            precincts = if_else(
                first(num_precincts) == n(),
                "-",
                str_flatten_comma(ward_precinct(ward, precinct))
            ),
            .groups = "drop"
        )
}

#' Get which districts serve a city/town
#' @param prec_dist Data frame from load_precinct_districts()
#' @param city_town_name City or town name
#' @return Data frame with office and district columns
get_city_town_representation <- function(prec_dist, city_town_name) {
    ct_data <- prec_dist |>
        filter(city_town == city_town_name)

    tibble(
        office = c("State Representative", "State Senate", "Governor's Council", "U.S. House"),
        districts = c(
            str_flatten_comma(unique(ct_data$State_Rep)),
            str_flatten_comma(unique(ct_data$State_Senate)),
            str_flatten_comma(unique(ct_data$Gov_Council)),
            str_flatten_comma(unique(ct_data$US_House))
        )
    )
}

# --- Geometry Queries ---

#' Get district geometry with info joined
#' @param office_geom sf object from load_office_geometry()
#' @param district_info Data frame from build_district_info()
#' @param office_name Office name
#' @return sf object with district boundaries and info
get_office_geometry_with_info <- function(office_geom, district_info, office_name) {
    office_geom |>
        select(-any_of("district_display")) |>
        mutate(office = office_name) |>
        left_join(
            district_info |> filter(office == office_name),
            by = c("office", "district")
        )
}

#' Get geometry for a specific district from precincts
#' @param prec_geom sf object from load_precinct_geometry()
#' @param prec_dist Data frame from load_precinct_districts()
#' @param office_name Office name
#' @param district_name District name
#' @return sf object with district boundary (dissolved from precincts)
get_district_geometry <- function(prec_geom, prec_dist, office_name, district_name) {
    office_col <- office_column(office_name)
    city_town_counts <- count_city_town_precincts(prec_dist)

    dist_pcts <- prec_dist |>
        filter(!!sym(office_col) == district_name) |>
        left_join(city_town_counts, by = "city_town") |>
        select(city_town, ward, precinct, num_precincts)

    prec_geom |>
        right_join(dist_pcts, by = c("city_town", "ward", "precinct")) |>
        filter(!st_is_empty(geometry)) |>
        group_by(city_town) |>
        summarize(
            label = if_else(
                first(num_precincts) == n(),
                first(city_town),
                str_glue("{first(city_town)} - {n()} of {first(num_precincts)} precincts")
            ),
            .groups = "drop"
        ) |>
        st_make_valid()
}

# --- Convenience Functions ---

#' List all legislative offices
#' @return Character vector of office names
list_offices <- function() {
    c("State Representative", "State Senate", "Governor's Council", "U.S. House")
}

#' List all districts for an office
#' @param district_info Data frame from build_district_info()
#' @param office_name Office name
#' @return Character vector of district names
list_districts <- function(district_info, office_name) {
    district_info |>
        filter(office == office_name) |>
        arrange(district_id) |>
        pull(district)
}

#' List all city/towns
#' @param prec_dist Data frame from load_precinct_districts()
#' @return Character vector of city/town names
list_city_towns <- function(prec_dist) {
    sort(unique(prec_dist$city_town))
}
