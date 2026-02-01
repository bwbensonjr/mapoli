# pvi/ma_pvi_maps.R
# Precinct-level PVI mapping functions for Massachusetts legislative districts
#
# This file provides interactive tmap visualizations of precinct-level
# Partisan Voting Index (PVI) within specified legislative districts.
# Blue shading indicates Democratic lean (positive PVI), red indicates
# Republican lean (negative PVI).

library(tidyverse)
library(sf)
library(tmap)
library(here)

# Source shared modules
source(here("R/ma_district_data.R"))
source(here("R/pvi_utils.R"))
source(here("R/district_utils.R"))
source(here("R/precinct_utils.R"))

#' Load precinct geometry joined with PVI calculations
#'
#' Loads precinct-district mapping with vote data, calculates PVI for each
#' precinct, and joins with precinct geometry.
#'
#' @return sf object with precinct geometry and PVI data
load_precinct_pvi_data <- function() {
    # Load precinct-district mapping with vote data
    prec_dist <- load_precinct_districts()

    # Load precinct geometry
    prec_geom <- load_precinct_geometry()

    # Add PVI calculations to precinct data
    prec_pvi <- prec_dist |>
        add_pvi_24() |>
        mutate(precinct_label = ward_precinct(
            replace_na(ward, "-"),
            replace_na(precinct, "1")
        ))

    # Join data with geometry
    prec_geom |>
        mutate(ward = replace_na(ward, "-")) |>
        left_join(prec_pvi, by = c("city_town", "ward", "precinct")) |>
        filter(!is.na(PVI_N)) |>
        st_make_valid()
}

#' Create an interactive map of precinct-level PVI for a district
#'
#' Displays an interactive tmap showing the Partisan Voting Index (PVI)
#' for each precinct within the specified legislative district. Blue
#' indicates Democratic lean, red indicates Republican lean.
#'
#' @param office_name Office name (e.g., "State Representative", "State Senate",
#'   "Governor's Council", "U.S. House")
#' @param district_name District name (e.g., "First Suffolk", "First Middlesex")
#' @return tmap object with interactive map
#'
#' @examples
#' \dontrun{
#' # State Representative district
#' district_pvi_map("State Representative", "First Suffolk")
#'
#' # State Senate district
#' district_pvi_map("State Senate", "First Middlesex")
#'
#' # U.S. House district
#' district_pvi_map("U.S. House", "Seventh")
#'
#' # Governor's Council district
#' district_pvi_map("Governor's Council", "Fourth")
#' }
district_pvi_map <- function(office_name, district_name) {
    # Set interactive mode
    tmap_mode("view")

    # Get the column name for the office
    office_col <- office_column(office_name)

    # Load precinct PVI data
    prec_pvi_geom <- load_precinct_pvi_data()

    # Filter to specified district
    dist_pvi <- prec_pvi_geom |>
        filter(!!sym(office_col) == district_name) |>
        filter(!st_is_empty(geometry))

    # Apply geometry cleanup (buffer and simplify)
    dist_pvi <- dist_pvi |>
        st_buffer(dist = 10) |>
        st_buffer(dist = -10) |>
        st_simplify(dTolerance = 25)

    # Custom diverging palette: skips lightest shades so small PVI values are visible
    # R+3 should appear noticeably red, D+3 noticeably blue
    pvi_colors <- c(
        "#67001F",
        "#B2182B",
        "#D6604D",
        "#F7F7F7",
        "#4393C3",
        "#2166AC",
        "#053061"
    )

    # Clamp PVI_N to limits so out-of-range values get darkest color (not grey)
    pvi_limit <- 15
    dist_pvi <- dist_pvi |>
        mutate(PVI_N_clamped = pmin(pmax(PVI_N, -pvi_limit), pvi_limit))

    # Create the map with diverging color scale
    # Limits set to ±15 so small values occupy more of the color range
    (tm_shape(dist_pvi) +
        tm_polygons(
            fill = "PVI_N_clamped",
            fill.scale = tm_scale_continuous(
                values = pvi_colors,
                midpoint = 0,
                limits = c(-pvi_limit, pvi_limit),
                labels = c("R+15+", "R+10", "R+5", "EVEN", "D+5", "D+10", "D+15+")
            ),
            fill.legend = tm_legend(title = "PVI"),
            fill_alpha = 0.7,
            popup.vars = c(
                "City/Town" = "city_town",
                "Precinct" = "precinct_label",
                "PVI" = "PVI",
                "Harris 2024" = "Harris_24",
                "Trump 2024" = "Trump_24"
            )
        ) +
        tm_basemap("OpenStreetMap"))
}
