library(tidyverse)

# Convert word ordinals to numeric format for district_display
# e.g., "First Bristol" -> "1st Bristol", "Twenty-Third Suffolk" -> "23rd Suffolk"
word_to_numeric_ordinal <- function(name) {
    ordinal_map <- c(
        "First" = "1st", "Second" = "2nd", "Third" = "3rd", "Fourth" = "4th",
        "Fifth" = "5th", "Sixth" = "6th", "Seventh" = "7th", "Eighth" = "8th",
        "Ninth" = "9th", "Tenth" = "10th", "Eleventh" = "11th", "Twelfth" = "12th",
        "Thirteenth" = "13th", "Fourteenth" = "14th", "Fifteenth" = "15th",
        "Sixteenth" = "16th", "Seventeenth" = "17th", "Eighteenth" = "18th",
        "Nineteenth" = "19th", "Twentieth" = "20th", "Twenty-First" = "21st",
        "Twenty-Second" = "22nd", "Twenty-Third" = "23rd", "Twenty-Fourth" = "24th",
        "Twenty-Fifth" = "25th", "Twenty-Sixth" = "26th", "Twenty-Seventh" = "27th",
        "Twenty-Eighth" = "28th", "Twenty-Ninth" = "29th", "Thirtieth" = "30th",
        "Thirty-First" = "31st", "Thirty-Second" = "32nd", "Thirty-Third" = "33rd",
        "Thirty-Fourth" = "34th", "Thirty-Fifth" = "35th", "Thirty-Sixth" = "36th",
        "Thirty-Seventh" = "37th"
    )
    str_replace_all(name, ordinal_map)
}

# Normalize ampersand to "and" for consistency with election data
normalize_ampersand <- function(name) {
    str_replace_all(name, " & ", " and ")
}

# Convert numeric ordinals to word format for district
# e.g., "1st Bristol" -> "First Bristol", "23rd Suffolk" -> "Twenty-Third Suffolk"
numeric_to_word_ordinal <- function(name) {
    ordinal_map <- c(
        "1st" = "First", "2nd" = "Second", "3rd" = "Third", "4th" = "Fourth",
        "5th" = "Fifth", "6th" = "Sixth", "7th" = "Seventh", "8th" = "Eighth",
        "9th" = "Ninth", "10th" = "Tenth", "11th" = "Eleventh", "12th" = "Twelfth",
        "13th" = "Thirteenth", "14th" = "Fourteenth", "15th" = "Fifteenth",
        "16th" = "Sixteenth", "17th" = "Seventeenth", "18th" = "Eighteenth",
        "19th" = "Nineteenth", "20th" = "Twentieth", "21st" = "Twenty-First",
        "22nd" = "Twenty-Second", "23rd" = "Twenty-Third", "24th" = "Twenty-Fourth",
        "25th" = "Twenty-Fifth", "26th" = "Twenty-Sixth", "27th" = "Twenty-Seventh",
        "28th" = "Twenty-Eighth", "29th" = "Twenty-Ninth", "30th" = "Thirtieth",
        "31st" = "Thirty-First", "32nd" = "Thirty-Second", "33rd" = "Thirty-Third",
        "34th" = "Thirty-Fourth", "35th" = "Thirty-Fifth", "36th" = "Thirty-Sixth",
        "37th" = "Thirty-Seventh"
    )
    str_replace_all(name, ordinal_map)
}

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

