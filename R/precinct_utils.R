# R/precinct_utils.R
# Precinct data manipulation utilities

library(tidyverse)

#' Fill missing ward and precinct values with defaults
#' @param df Data frame with ward and precinct columns
#' @return Data frame with NA values replaced
fill_missing_ward_precinct <- function(df) {
    df %>%
        mutate(ward = replace_na(ward, "-"),
               precinct = replace_na(precinct, "1"))
}

#' Combine ward and precinct into single string
#' @param ward Ward identifier
#' @param precinct Precinct identifier
#' @return Combined ward-precinct string
ward_precinct <- function(ward, precinct) {
    if_else(ward == "-",
            precinct,
            str_c(ward, "-", precinct))
}

#' Combine child precincts into parent precincts
#' @param df Data frame with precinct-level data
#' @param parentage Tribble mapping child precincts to parents
#' @return Data frame with combined precinct data
combine_precincts <- function(df, parentage) {
    # Identify join columns
    join_cols <- c("city_town", "ward", "precinct")

    # District identifier columns that should be preserved, not aggregated
    # These represent district assignments and must remain consistent within each precinct
    district_id_cols <- c("State_Rep", "State_Senate", "Gov_Council", "US_House")

    # Vote columns are numeric columns that should be summed when combining precincts
    all_numeric_cols <- names(df)[sapply(df, is.numeric)]
    vote_cols <- setdiff(all_numeric_cols, district_id_cols)

    # Identifier columns for grouping (district IDs + any other non-vote columns)
    identifier_cols <- setdiff(names(df), c(join_cols, vote_cols))

    # Merge the parentage information with the original dataframe
    df_with_parents <- df %>%
        left_join(parentage, by = join_cols)

    # Separate parent and child rows
    parent_rows <- df_with_parents %>%
        filter(is.na(parent_precinct))

    child_rows <- df_with_parents %>%
        filter(!is.na(parent_precinct))

    # Aggregate child rows
    aggregated_children <- child_rows %>%
        group_by(city_town, ward, parent_precinct, across(all_of(identifier_cols))) %>%
        summarize(across(all_of(vote_cols), sum), .groups = "drop") %>%
        ungroup() %>%
        rename(precinct = parent_precinct)

    # Combine parent rows with aggregated child rows
    combined <- parent_rows %>%
        select(-parent_precinct) %>%
        bind_rows(aggregated_children) %>%
        group_by(across(all_of(c(join_cols, identifier_cols)))) %>%
        summarize(across(all_of(vote_cols), sum), .groups = "drop") %>%
        ungroup()

    return(combined)
}

# Precinct combination mappings for 2024 elections
combine_24 <- tribble(
    ~city_town, ~ward, ~precinct, ~parent_precinct,
    "Chicopee", "6", "AN", "A",
    "Chicopee", "6", "AS", "A",
    "Chicopee", "6", "BE", "B",
    "Chicopee", "6", "BW", "B",
    "Warren", "-", "A", "1",
    "Warren", "-", "B", "1",
    "Groton", "-", "3A", "1",
    "Dracut", "-", "6A", "6",
    "Hingham", "-", "7A", "7",
    "Newburyport", "1", "P", "1",
    "Peabody", "4", "3A", "3",
    "Revere", "5", "1A", "1"
)

# Precinct combination mappings for 2022 elections
combine_22 <- tribble(
    ~city_town, ~ward, ~precinct, ~parent_precinct,
    "Groton", "-", "3A", "1"
)
