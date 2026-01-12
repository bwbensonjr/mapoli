# R/pvi_utils.R
# Partisan Voting Index calculation utilities

library(tidyverse)

# National baseline vote totals
US_Harris_24 <- 75017626
US_Trump_24 <- 77301997
US_Biden_20 <- 81281502
US_Trump_20 <- 74222593
US_Clinton_16 <- 65853514
US_Trump_16 <- 62984828

#' Calculate Democratic percentage from two elections
#' @param dem_2 Democratic votes in more recent election
#' @param gop_2 Republican votes in more recent election
#' @param dem_1 Democratic votes in earlier election
#' @param gop_1 Republican votes in earlier election
#' @return Democratic vote percentage
dem_percent <- function(dem_2, gop_2, dem_1, gop_1) {
    dem_votes <- dem_2 + dem_1
    gop_votes <- gop_2 + gop_1
    dem_pct <- dem_votes / (dem_votes + gop_votes)
    dem_pct
}

#' Calculate Democratic percentage from single election
#' @param dem Democratic votes
#' @param gop Republican votes
#' @return Democratic vote percentage
dem_percent_1 <- function(dem, gop) {
    dem / (dem + gop)
}

#' Convert numeric PVI to display string
#' @param pvi_n Numeric PVI value
#' @return PVI string (e.g., "D+5", "R+3", "EVEN")
pvi_string <- function(pvi_n) {
    case_when(
        pvi_n <= -0.5 ~ str_c("R+", round(abs(pvi_n))),
        pvi_n >= 0.5 ~ str_c("D+", round(pvi_n)),
        TRUE ~ "EVEN"
    )
}

# Pre-calculated national baselines
US_PVI_24 <- dem_percent(US_Harris_24, US_Trump_24, US_Biden_20, US_Trump_20)
US_PVI_20 <- dem_percent(US_Biden_20, US_Trump_20, US_Clinton_16, US_Trump_16)

#' Add 2024 PVI columns to data frame
#' @param df Data frame with Harris_24, Trump_24, Biden_20, Trump_20 columns
#' @return Data frame with PVI_N and PVI columns added
add_pvi_24 <- function(df) {
    df |>
        mutate(PVI_N = (dem_percent(Harris_24, Trump_24, Biden_20, Trump_20) - US_PVI_24) * 100,
               PVI = pvi_string(PVI_N))
}

#' Add 2020 PVI columns to data frame
#' @param df Data frame with Biden_20, Trump_20, Clinton_16, Trump_16 columns
#' @return Data frame with PVI_N_20 and PVI_20 columns added
add_pvi_20 <- function(df) {
    df |>
        mutate(PVI_N_20 = ((dem_percent(Biden_20, Trump_20, Clinton_16, Trump_16) - US_PVI_20) * 100),
               PVI_20 = pvi_string(PVI_N_20))
}

#' Add all PVI-related calculations
#' @param df Data frame with election data columns
#' @return Data frame with all PVI and shift calculations
add_calculations <- function(df) {
    df |>
        mutate(dem_pct_24 = dem_percent_1(Harris_24, Trump_24),
               dem_pct_20 = dem_percent_1(Biden_20, Trump_20),
               dem_pct_16 = dem_percent_1(Clinton_16, Trump_16)) |>
        add_pvi_24() |>
        add_pvi_20() |>
        mutate(shift_20_24 = dem_pct_24 - dem_pct_20,
               pvi_shift = PVI_N - PVI_N_20)
}
