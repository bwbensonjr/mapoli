library(tidyverse)

unabbreviate_compass <- function(name) {
    str_replace_all(name,
                    fixed(c("N. " = "North ",
                            "E. " = "East ",
                            "S. " = "South ",
                            "W. " = "West ")))
}

fill_missing_ward_precinct <- function(df) {
    df %>%
        mutate(ward = replace_na(ward, "-"),
               precinct = replace_na(precinct, "1"))
}

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

combine_22 <- tribble(
    ~city_town, ~ward, ~precinct, ~parent_precinct,
    "Groton", "-", "3A", "1",
)

combine_precincts <- function(df, parentage) {
  # Identify join columns
  join_cols <- c("city_town", "ward", "precinct")
  
  # Identify numeric columns
  numeric_cols <- names(df)[sapply(df, is.numeric)]
  
  # Identify other columns to preserve
  other_cols <- setdiff(names(df), c(join_cols, numeric_cols))
  
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
    group_by(city_town, ward, parent_precinct, across(all_of(other_cols))) %>%
    summarize(across(all_of(numeric_cols), sum)) %>%
    ungroup() %>%
    rename(precinct = parent_precinct)
  
  # Combine parent rows with aggregated child rows
  combined <- parent_rows %>%
    select(-parent_precinct) %>%
    bind_rows(aggregated_children) %>%
    group_by(across(all_of(c(join_cols, other_cols)))) %>%
    summarize(across(all_of(numeric_cols), sum)) %>%
    ungroup()
  
  return(combined)
}

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

# comb_results %>% write_csv("ma_precincts_districts_pres_2024.csv")
comb_results <- read_csv("ma_precincts_districts_pres_2024.csv")

US_Harris_24 <- 75017626
US_Trump_24 <- 77301997
US_Biden_20 <- 81281502
US_Trump_20 <- 74222593
US_Clinton_16 <- 65853514
US_Trump_16 <- 62984828

dem_percent <- function(dem_2, gop_2, dem_1, gop_1) {
    dem_votes <- dem_2 + dem_1
    gop_votes <- gop_2 + gop_1
    dem_pct <- dem_votes/(dem_votes + gop_votes)
    dem_pct
}

dem_percent_1 <- function(dem_1, gop_1) {
    dem_pct <- dem_1/(dem_1 + gop_1)
    dem_pct
}

pvi_string <- function(pvi_n) {
    case_when(
        pvi_n <= -0.5 ~ str_c("R+", round(abs(pvi_n))),
        pvi_n >= 0.5 ~ str_c("D+", round(pvi_n)),
        TRUE ~ "EVEN",
    )
}

US_PVI_24 <- dem_percent(
    US_Harris_24,
    US_Trump_24,
    US_Biden_20,
    US_Trump_20
)

US_PVI_20 <- dem_percent(
    US_Biden_20,
    US_Trump_20,
    US_Clinton_16,
    US_Trump_16
)

add_pvi_24 <- function(df) {
    df |>
        mutate(PVI_N = (dem_percent(Harris_24,
                                    Trump_24,
                                    Biden_20,
                                    Trump_20) - US_PVI_24) * 100,
               PVI = pvi_string(PVI_N))
}

add_pvi_20 <- function(df) {
    df |>
        mutate(PVI_N_20 = ((dem_percent(Biden_20,
                                        Trump_20,
                                        Clinton_16,
                                        Trump_16) - US_PVI_20) * 100),
               PVI_20 = pvi_string(PVI_N_20))
}

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
