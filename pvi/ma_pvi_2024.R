library(tidyverse)
library(here)

# Source shared utilities
source(here("R/geo_utils.R"))
source(here("R/district_utils.R"))
source(here("R/precinct_utils.R"))
source(here("R/pvi_utils.R"))

pres_24 <- read_csv("../results/MA-President-2024-11-05.csv") %>%
    fill_missing_ward_precinct() %>%
    select(-c(office, district)) %>%
    mutate(city_town = unabbreviate_compass(city_town),
           receiver = str_replace(receiver,
                                  "Alice R. Harris",
                                  "Harris_24"),
           receiver = str_replace(receiver,
                                  "Kamala Harris",
                                  "Harris_24"),
           receiver = str_replace(receiver,
                                  "Donald J. Trump",
                                  "Trump_24")) %>%
    filter(receiver %in% c("Harris_24", "Trump_24")) %>%
    pivot_wider(id_cols=c(city_town, ward, precinct),
                names_from=receiver,
                values_from=votes) %>%
    combine_precincts(combine_24)

comb_results <- read_csv("ma_precincts_districts_pres_2022.csv") %>%
    combine_precincts(combine_22) %>%
    left_join(pres_24, by=c("city_town", "ward", "precinct")) %>%
    mutate(Harris_24 = replace_na(Harris_24, 0),
           Trump_24 = replace_na(Trump_24, 0))

comb_results %>% write_csv("ma_precincts_districts_pres_2024.csv")
# comb_results <- read_csv("ma_precincts_districts_pres_2024.csv")

ma_pvi <- comb_results |>
    select(-US_House) |>
    summarize(across(where(is.numeric), sum)) |>
    add_calculations()

ma_pvi |>
    write_csv("ma_state_pres_pvi_2024.csv")

state_rep_pvi <- comb_results %>%
    select(-US_House) |>
    group_by(State_Rep) |>
    summarize(across(where(is.numeric), sum)) |>
    add_calculations()

state_rep_pvi %>%
    write_csv("ma_state_rep_pres_pvi_2024.csv")

state_senate_pvi <- comb_results %>%
    select(-US_House) |>
    group_by(State_Senate) |>
    summarize(across(where(is.numeric), sum)) |>
    add_calculations()

state_senate_pvi %>%
    write_csv("ma_state_senate_pres_pvi_2024.csv")

gov_council_pvi <- comb_results %>%
    select(-US_House) |>
    group_by(Gov_Council) |>
    summarize(across(where(is.numeric), sum)) |>
    add_calculations()

gov_council_pvi %>%
    write_csv("ma_gov_council_pres_pvi_2024.csv")

us_house_pvi <- comb_results %>%
    group_by(US_House) |>
    summarize(across(where(is.numeric), sum)) |>
    add_calculations()
    
us_house_pvi %>%
    write_csv("ma_us_house_pres_pvi_2024.csv")

## Combine into single file for legislative offices

state_rep_pvi <-
    read_csv("ma_state_rep_pres_pvi_2024.csv") |>
    mutate(office = "State Representative",
           district = normalize_ampersand(State_Rep),
           district_display = word_to_numeric_ordinal(normalize_ampersand(State_Rep))) |>
    select(office, district, district_display, PVI, PVI_N)

state_senate_pvi <-
    read_csv("ma_state_senate_pres_pvi_2024.csv") |>
    mutate(office = "State Senate",
           district = normalize_ampersand(State_Senate),
           district_display = word_to_numeric_ordinal(normalize_ampersand(State_Senate))) |>
    select(office, district, district_display, PVI, PVI_N)

gov_council_pvi <-
    read_csv("ma_gov_council_pres_pvi_2024.csv") |>
    mutate(office = "Governor's Council",
           district = as.character(Gov_Council),
           district_display = as.character(Gov_Council)) |>
    select(office, district, district_display, PVI, PVI_N)

us_house_pvi <-
    read_csv("ma_us_house_pres_pvi_2024.csv") |>
    mutate(office = "U.S. House",
           district = as.character(US_House),
           district_display = as.character(US_House)) |>
    select(office, district, district_display, PVI, PVI_N)

legislative_pvi <-
   bind_rows(
       state_rep_pvi,
       state_senate_pvi,
       gov_council_pvi,
       us_house_pvi
   )

legislative_pvi |>
    write_csv("ma_legislative_district_pvi_2024.csv")

# Historical file has `district` in numeric format (e.g., "1st Bristol")
# which is actually district_display. Fix column names, normalize "&" to "and",
# and add word-format district.
hist_pvi_2022 <- read_csv("ma_state_leg_pvi_2008_2022.csv") |>
    rename(district_display = district) |>
    mutate(district_display = normalize_ampersand(district_display),
           district = numeric_to_word_ordinal(district_display)) |>
    select(pvi_year, office, district, district_display, PVI_N, PVI)

hist_pvi <-
    rbind(
        hist_pvi_2022,
        (legislative_pvi |>
         filter(office %in% c("State Representative", "State Senate")) |>
         mutate(pvi_year = 2024) |>
         select(pvi_year, office, district, district_display, PVI_N, PVI))
    )

hist_pvi |>
    write_csv("ma_state_leg_pvi_2008_2024.csv")

