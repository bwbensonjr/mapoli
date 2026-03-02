### Analyze and display election election results
library(tidyverse)
library(sf)
library(tmap)
library(here)

source(here("R/ma_district_data.R"))
source(here("R/precinct_utils.R"))

standard_columns <- c(
    "blanks",
    "all_others",
    "total_votes"
)

last_name <- function(names) {
    str_extract(names, "\\S+$")
}

## Convert tidy formatted precinct-level results to a
## row per precinct with a NAME_pct column for each
## candidate.
load_precinct_results <- function(file_name, elec_id) {
    tidy_votes <- read_csv(file_name) |>
        filter(election_id == elec_id)
    candidates <- tidy_votes |>
        filter(!(name %in% standard_columns)) |>
        pull(name) |>
        unique()
    last_names <- last_name(candidates)
    tidy_votes |>
        mutate(name = if_else(name %in% standard_columns, name, last_name(name))) |>
        select(-candidate_id) |>
        pivot_wider(names_from = name, values_from = votes) |>
        filter(total_votes > 0) |>
        mutate(across(
            all_of(last_names),
            ~ . / (total_votes - blanks),
            .names = "{.col}_pct"
        ))
}

## Join precinct results with precinct geometry from the
## wards_pcts_subs_2022.geojson file.
add_precinct_geometry <- function(results, with_subs=TRUE) {
    prec_geom <- load_precinct_geometry(with_subs=with_subs)
    prec_geom |>
        mutate(ward = replace_na(ward, "-")) |>
        inner_join(results, by = c("city_town", "ward", "precinct")) |>
        mutate(precinct_label = ward_precinct(ward, precinct)) |>
        filter(!st_is_empty(geometry)) |>
        st_make_valid()
}

## Display an interactive tmap of precinct-level results with
## graduated colors per candidate. Each candidate who wins at
## least one precinct gets their own color ramp and legend.
precinct_result_map <- function(results_sf) {
    tmap_mode("view")

    ## Identify candidate columns from the _pct suffix
    pct_cols <- str_subset(names(results_sf), "_pct$")
    candidates <- str_remove(pct_cols, "_pct$")

    ## Create display percentage columns (0-100) for popups
    for (cand in candidates) {
        results_sf[[paste0(cand, "_display_pct")]] <-
            round(results_sf[[paste0(cand, "_pct")]] * 100, 1)
    }

    ## Determine winner per precinct (highest vote share)
    pct_data <- st_drop_geometry(results_sf) |> select(all_of(pct_cols))
    results_sf$winner <- candidates[max.col(pct_data, ties.method = "first")]

    ## Apply geometry cleanup (buffer out/in to close gaps, then simplify)
    results_sf <- results_sf |>
        st_buffer(dist = 10) |>
        st_buffer(dist = -10) |>
        st_simplify(dTolerance = 25)

    ## One color ramp (light → dark) per candidate
    palette_bases <- list(
        c("#DEEBF7", "#08519C"),
        c("#FEE0D2", "#A50F15"),
        c("#E5F5E0", "#006D2C"),
        c("#F2E5FF", "#6A0DAD"),
        c("#FFF3CD", "#D4750B")
    )
    candidate_palettes <- setNames(
        palette_bases[seq_along(candidates)],
        candidates
    )

    ## Build popup variables showing every candidate's results
    popup_vars <- c(
        "City/Town" = "city_town",
        "Precinct" = "precinct_label",
        "Winner" = "winner",
        "Total Votes" = "total_votes"
    )
    for (cand in candidates) {
        popup_vars[cand] <- cand
        popup_vars[paste0(cand, " %")] <- paste0(cand, "_display_pct")
    }

    ## Layer one tm_shape per candidate so each gets its own color ramp
    map <- tm_basemap("OpenStreetMap")
    for (cand in candidates) {
        cand_sf <- results_sf |> filter(winner == cand)
        if (nrow(cand_sf) > 0) {
            display_col <- paste0(cand, "_display_pct")
            map <- map +
                tm_shape(cand_sf) +
                tm_polygons(
                    fill = display_col,
                    fill.scale = tm_scale_continuous(
                        values = candidate_palettes[[cand]],
                        limits = c(0, 100)
                    ),
                    fill.legend = tm_legend(title = paste0(cand, " %")),
                    fill_alpha = 0.7,
                    popup.vars = popup_vars
                )
        }
    }
    map
}
