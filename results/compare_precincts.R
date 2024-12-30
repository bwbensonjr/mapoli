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

ward_precinct_fixes <- function (df) {
    df %>%
        mutate(ward = case_when(
                    ((city_town == "Agawam") & is.na(ward)) ~ "-",
                    TRUE ~ ward),
               precinct = case_when(
                    ((city_town == "Agawam") & is.na(precinct)) ~ "1",
                    TRUE ~ precinct))
}

office_results <- function(csv_file, suffix) {
    read_csv(csv_file, col_types=cols(district=col_character())) %>%
        fill_missing_ward_precinct() %>%
        mutate(city_town = unabbreviate_compass(city_town)) %>%
        filter(receiver == "Total Votes Cast") %>%
        select(city_town,
               ward,
               precinct,
               votes,
               district) %>%
        mutate(district = replace_na(district, "-")) %>%
        rename_with(~paste0(., suffix),
                    .cols=c(votes, district))
}

gov_22 <- office_results("MA-Governor-2022-11-08.csv", "_gov_22")
# sr_22 <- office_results("MA-State Representative-2022-11-08.csv", "_sr_22")
sen_22 <- office_results("MA-State Senate-2022-11-08.csv", "_sen_22")
sr_24 <- office_results("MA-State Representative-2024-11-05.csv", "_sr_24")
sen_24 <- office_results("MA-State Senate-2024-11-05.csv", "_sen_24")
us_house_24 <- office_results("MA-U.S. House-2024-11-05.csv", "_us_house_24")
pres_24 <- office_results("MA-President-2024-11-05.csv", "_pres_24")

comp <- sen_22 %>% full_join(sen_24, by=c("city_town", "ward", "precinct")) 

comp %>% filter(is.na(votes_sen_22) | is.na(votes_sen_24))

comp_2 <- gov_22 %>% full_join(sen_24, by=c("city_town", "ward", "precinct"))

comp_sen <- sen_22 %>%
    full_join(sen_24,
              by=c("city_town", "ward", "precinct")) %>%
    filter(is.na(votes_sen_22) | is.na(votes_sen_24))

sub_pcts_22 <- read_csv("../pvi/ma_precincts_w_subs_pres_2022.csv") %>%
    mutate(votes_pres_20 = Biden_20 + Trump_20) %>%
    select(city_town, ward, precinct, votes_pres_20)

pres_comp <- pres_24

comp_22_24 <- pres_24 %>%
    select(-district_pres_24) %>%
    full_join(sub_pcts_22, by=c("city_town", "ward", "precinct"))

comp_22_24 %>%
    filter(is.na(votes_pres_24) | is.na(votes_pres_20))

comp_22_24 %>%
    filter((is.na(votes_pres_24) & (votes_pres_20 != 0)) |
           (is.na(votes_pres_20) & (votes_pres_24 != 0)))

##    city_town   ward  precinct votes_pres_24 votes_pres_20

## The old numbers for Chicopee precinct 6 are in only two
## precincts, `A` and `B`, while the latest numbers are
## across 4 precincts. Our map has two precincts so we
## will combine 4 into 2.
## old numbers into the 4 precincts.
##  1 Chicopee    6     AN                 539           NA 
##  2 Chicopee    6     AS                 954           NA 
##  3 Chicopee    6     BE                1491           NA 
##  4 Chicopee    6     BW                 303           NA 
## 12 Chicopee    6     A                   NA         1439.
## 13 Chicopee    6     B                   NA         1829 

## Similarly, Warren has two precincts, `A` and `B`, while
## the old numbers have a single, town-wide precinct. Our map
## has just a single precinct so we will combine 2 to 1.
## 10 Warren      -     A                 2019           NA 
## 11 Warren      -     B                  661           NA 
## 15 Warren      -     1                   NA         1865 

## Groton has gotten rid of precinct `3A` through legislation
## and made it part of precinct `1`. Old `3A` votes should
## be added to precinct `1` votes.
## 14 Groton      -     3A                  NA          188.

## The following precincts seem to be sub-precincts that aren't
## present in the old data. It might make sense to check on
## the official standing of these precincts and to see if they
## are in different districts than the "parent" precinct. After
## checking, there are no district differences for State Rep,
## State Senate, or U.S. House. Because the map does not have
## these precincts, we will combine into the parent precinct.
##  5 Dracut      -     6A                  82           NA 
##  6 Hingham     -     7A                1210           NA 
##  7 Newburyport 1     P                  480           NA 
##  8 Peabody     4     3A                1519           NA 
##  9 Revere      5     1A                 643           NA 

parent_precincts <- tribble(
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

precinct_columns <- c("city_town", "ward", "precinct")

combine_precincts <- function(df, parentage) {
  # Identify numeric columns
  numeric_cols <- names(df)[sapply(df, is.numeric)]
  
  # Merge the parentage information with the original dataframe
  df_with_parents <- df %>%
    left_join(parentage, by = c("city_town", "ward", "precinct"))
  
  # Separate parent and child rows
  parent_rows <- df_with_parents %>%
    filter(is.na(parent_precinct))
  
  child_rows <- df_with_parents %>%
    filter(!is.na(parent_precinct))
  
  # Aggregate child rows
  aggregated_children <- child_rows %>%
    group_by(city_town, ward, parent_precinct) %>%
    summarize(across(all_of(numeric_cols), sum)) %>%
    ungroup() %>%
    rename(precinct = parent_precinct)
  
  # Combine parent rows with aggregated child rows
  combined <- parent_rows %>%
    select(-parent_precinct) %>%
    bind_rows(aggregated_children) %>%
    group_by(city_town, ward, precinct) %>%
    summarize(across(all_of(numeric_cols), sum)) %>%
    ungroup()
  
  return(combined)
}

comp_22_24 <- pres_24 %>%
    combine_precincts(parent_precincts) %>%
    full_join(sub_pcts_22, by=c("city_town", "ward", "precinct"))


wp_22 <- read_sf("../gis/geojson/wardsprecincts2022.geojson")
wp_subs_22 <- read_sf("../gis/geojson/wards_pcts_subs_2022.geojson") %>%
    rename(ward = Ward, precinct = Pct)

pres_24_geom <- wp_subs_22 %>%
    full_join(pres_24, by=c("city_town", "ward", "precinct"))
