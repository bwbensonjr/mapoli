library(tidyverse)
library(here)

ct_demos <-
    read_csv(here("demographics", "data", "ma_city_town_demographics.csv"))

pct_demos <-
    read_csv(here("demographics", "data", "ma_precinct_demographics.csv"))

pcts <-
    read_csv(here("pvi", "ma_precincts_districts_pres_2024.csv")) |>
    left_join(
        pct_demos,
        by = c("city_town", "ward", "precinct")
    )

ct_summary <- pcts |>
    group_by(city_town) |>
    summarize(
        num_precincts = n(),
        total_population = sum(total_population),
        num_state_rep_dists = length(unique(State_Rep)),
        num_state_senate_dists = length(unique(State_Senate)),
        num_us_house_dists = length(unique(US_House))
    )

