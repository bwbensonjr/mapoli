## Map the 2016 and 2022 presidential votes from pre-2021 wards
## and precincts to the new post-2022 wards and precincts,
## including sub-precincts.

library(tidyverse)
library(sf)
library(tigris)
library(tidycensus)
library(tmap)

wp_votes_ng <- read_csv("ma_precincts_pvi_2022.csv") %>%
    select(-c(PVI, PVI_N)) %>%
    rename(ward = Ward,
           precinct = Pct)

wp_votes <- read_sf("../gis/geojson/wardsprecincts2022.geojson") %>%
    st_transform(6491) %>%
    left_join(wp_votes_ng, by=c("city_town", "ward", "precinct")) %>%
    select(city_town, ward, precinct, Biden_20, Trump_20, Clinton_16, Trump_16)

wp_subs <- read_sf("../gis/geojson/wards_precincts_w_subs.geojson") %>%
    st_transform(6491) %>%
    select(city_town, ward, precinct)

## Calculate the new subprecincts introduced
wp_subs_ng <- wp_subs %>%
    st_drop_geometry()

new_subs <- wp_subs_ng %>%
    anti_join(wp_votes_ng)

## Interpolate changes to vote totals introduced by subprecincts
census_blocks <- blocks(state="25") %>%
    select(block_fips = GEOID20,
           population = POP20) %>%
    st_transform(6491)

sub_vote_estimates <- interpolate_pw(from=wp_votes,
                                     to=wp_subs,
                                     weights=census_blocks,
                                     weight_column="population",
                                     crs=6491,
                                     extensive=TRUE) %>%
    st_drop_geometry() %>%
    select(Biden_20, Trump_20, Clinton_16, Trump_16)

wp_sub_votes_geom <- cbind(wp_subs, sub_vote_estimates)

wp_sub_votes <- wp_sub_votes_geom %>%
    st_drop_geometry() %>%
    as_tibble()

wp_sub_votes %>%
    write_csv("ma_precincts_w_subs_pres_2022.csv")


## Add districts with subprecincts

wp_sub_votes_dists <- read_csv("ma_districts_precincts_2022.csv") %>%
    rename(ward = Ward, precinct = Pct) %>%
    left_join(wp_sub_votes, by=c("city_town", "ward", "precinct")) %>%
    ## Remove Boston 6-12A since it is in the water and has no votes
    filter(!(city_town == "Boston" & ward == "6" & precinct == "12A"))

wp_sub_votes_dists %>%
    write_csv("ma_precincts_districts_pres_2022.csv")
                                 
## Merge original vote toals back in for comparison
## wp_votes_orig <- wp_votes_ng %>%
##     select(-c(Trump_20, Clinton_16, Trump_16)) %>%
##     rename(Biden_20_orig = Biden_20)

## wp_sub_compare <- wp_sub_votes %>%
##     left_join(wp_votes_orig,
##               by=c("city_town",
##                    "ward",
##                    "precinct")) %>%
##     replace_na(list(Biden_20_orig = 0)) %>%
##     mutate(Biden_diff = Biden_20 - Biden_20_orig)

## wp_changed <- wp_sub_compare %>%
##     filter(Biden_diff != 0)
