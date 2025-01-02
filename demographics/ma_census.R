library(tidyverse)
library(tidycensus)
library(sf)
library(tigris)
library(glue)

## Read the table of variables we want to capture or use
message("Reading census variables to collect...")
census_vars <- read_csv("census_vars.csv")

## The set of variables that are only used for calculations but
## aren't kept around after use.
temp_var_names <- census_vars %>%
    filter(!keep) %>%
    pull(var_name)

census_query <- function(geography, vars, state=NULL) {
    get_acs(geography=geography,
            variables=vars$variable,
            year=2022,
            state=state) %>%
        left_join(vars, by="variable") %>%
        pivot_wider(id_cols=c("GEOID", "NAME"),
                    names_from="var_name",
                    values_from="estimate")
}

add_calculated_factors <- function(df) {
    df %>%
        mutate(ed_college_degree = (ed_bachelors +
                                    ed_masters +
                                    ed_professional +
                                    ed_doctorate),
               ed_some_college = (ed_college_lt_1 +
                                  ed_college_gt_1 +
                                  ed_associates +
                                  ed_college_degree),
               race_minority = (race_black +
                                race_native_american +
                                race_asian +
                                race_hawaiian +
                                race_other +
                                race_multiracial +
                                   race_hispanic),
               vote_male_eligible = (vote_male_native_18_plus +
                                     vote_male_naturalized_18_plus),
               vote_female_eligible = (vote_female_native_18_plus +
                                       vote_female_naturalized_18_plus),
               vote_eligible = (vote_male_eligible +
                                vote_female_eligible))
}

add_percentage_factors <- function(df) {
    df %>%
        mutate(gender_female_pct = gender_female / total_population,
               below_poverty_pct = below_poverty_level / poverty_total,
               ed_college_degree_pct = ed_college_degree / total_population,
               ed_some_college_pct = ed_some_college / total_population,
               race_minority_pct = race_minority / total_population,
               race_white_pct = race_white / total_population,
               race_black_pct = race_black / total_population,
               race_asian_pct = race_asian / total_population,
               race_hispanic_pct = race_hispanic / total_population,
               race_native_pct = race_native_american / total_population,
               poverty_pct = below_poverty_level / poverty_total,
               vote_female_pct = vote_female_eligible / vote_eligible,
               wwc_pct = (white_nh_male_lt_high_school +
                          white_nh_male_high_school_grad +
                          white_nh_male_some_college +
                          white_nh_female_lt_high_school +
                          white_nh_female_high_school_grad +
                          white_nh_female_some_college) / total_population,
               white_college_pct = ((white_nh_male_bachelors_or_gt +
                                     white_nh_female_bachelors_or_gt) /
                                    total_population))
}

city_town_name <- function(comp_name) {
    first_part <- str_split_fixed(comp_name, ", ", 3)[,1]
    str_replace_all(first_part, c(" Town city" = "",
                                  " town" = "",                    
                                  " city" = ""))
}

city_town_county <- function(comp_name) {
    first_part <- str_split_fixed(comp_name, ", ", 3)[,2]
    str_replace(first_part, " County", "")
}

## city_town_vars <- census_query("county subdivision",
##                                census_vars,
##                                state=25) %>%
##     filter(!str_detect(NAME, "not defined")) %>%
##     mutate(city_town = city_town_name(NAME),
##            county = city_town_county(NAME)) %>%
##     rename(city_town_fips = GEOID) %>%
##     select(-NAME) %>%
##     add_calculated_factors() %>%
##     add_percentage_factors() %>%
##     select(-all_of(temp_var_names))

## county_vars <- census_query("county",
##                                census_vars,
##                             state=25) %>%
##     mutate(county = str_replace(NAME, " County, Massachusetts", "")) %>%
##     rename(county_fips = GEOID) %>%
##     select(-NAME) %>%
##     add_calculated_factors() %>%
##     add_percentage_factors() %>%
##     select(-all_of(temp_var_names))

## cong_dist_vars <- get_acs(geography="congressional district",
##                           variables=census_vars$variable,
##                           year=2022,
##                           sumfile="cd118",
##                           state=25) %>%
##     left_join(census_vars, by="variable") %>%
##     pivot_wider(id_cols=c("GEOID", "NAME"),
##                 names_from="var_name",
##                 values_from="estimate") %>%
##     add_calculated_factors() %>%
##     add_percentage_factors() %>%
##     select(-all_of(temp_var_names))

## The new MA State Rep and State Senate districts
## are different from the ones known by the census so
## the variable values need to be interpolated.
##
## It looks like we need to do the interpolation
## in three different cases:
## - block groups, extensive=TRUE (counts of things)
## - block groups, extensive=FALSE (e.g., central/median values)
## - tracts, extensive=TRUE
## - tracts, extensive=FALSE (we don't have this case)
##
block_group_count_vars <- census_vars %>%
    filter(geography == "block group", count)
block_group_median_vars <- census_vars %>%
    filter(geography == "block group", !count)
tract_count_vars <- census_vars %>%
    filter(geography == "tract")

message("Reading block geometry...")
block_geom <- blocks(state=25, year=2022) %>%
    st_transform(6491)

message("Reading block group geometry...")
block_group_geom <- block_groups(state=25,
                                 cb=TRUE,
                                 year=2022) %>%
    st_transform(6491) %>%
    select(GEOID)

message("Reading tract geometry...")
tract_geom <- tracts(state=25,
                     cb=TRUE,
                     year=2022) %>%
    st_transform(6491) %>%
    select(GEOID)

message("Reading block group counts and medians...")
block_group_counts <- block_group_geom %>%
    left_join(census_query("block group",
                           block_group_count_vars,
                           state=25),
              by="GEOID")

block_group_medians <- block_group_geom %>%
    left_join(census_query("block group",
                           block_group_median_vars,
                           state=25),
              by="GEOID")

message("Reading tract counts...")
tracts <- tract_geom %>%
    left_join(census_query("tract",
                           tract_count_vars,
                           state=25),
              by="GEOID")

## It looks like we need to do the interpolation
## in three different cases:
## - block groups, extensive=TRUE
## - block groups, extensive=FALSE (e.g., median vars)
## - tracts, extensive=TRUE
## - tracts, extensive=FALSE (we don't have this case)
##
interpolate_geom <- function(target_geom, target_id, target_crs) {
    target_block_group_counts <- interpolate_pw(block_group_counts,
                                                target_geom,
                                                weights=block_geom,
                                                to_id=target_id,
                                                extensive=TRUE,
                                                crs=target_crs) %>%
        as_tibble() %>%
        select(-geometry)
    target_block_group_medians <- interpolate_pw(block_group_medians,
                                                 target_geom,
                                                 weights=block_geom,
                                                 to_id=target_id,
                                                 extensive=FALSE,
                                                 crs=target_crs) %>%
        as_tibble() %>%
        select(-geometry)
    target_tract_counts <- interpolate_pw(tracts,
                                          target_geom,
                                          weights=block_geom,
                                          to_id=target_id,
                                          extensive=TRUE,
                                          crs=target_crs) %>%
        as_tibble() %>%
        select(-geometry)
    target_block_group_counts %>%
        left_join(target_block_group_medians, by=target_id) %>%
        left_join(target_tract_counts, by=target_id) %>%
        add_calculated_factors() %>%
        add_percentage_factors() %>%
        select(-all_of(temp_var_names)) %>%
        add_geometry_area(target_geom, target_id)
}

message("Interpolating State Rep values...")
state_rep_geom <- read_sf("../gis/geojson/house2021.geojson")
state_rep_vars <- interpolate_geom(state_rep_geom, "district", 6491)
state_rep_file_name <- "data/ma_state_rep_demographics.csv"
message(glue("Writing State Rep variables to file {state_rep_file_name}..."))
state_rep_vars |> write_csv(state_rep_file_name)

message("Interpolating State Senate values...")
state_senate_geom <- read_sf("../gis/geojson/senate2021.geojson")
state_senate_vars <- interpolate_geom(state_senate_geom, "district", 6491) 
state_senate_file_name <- "data/ma_state_senate_demographics.csv"
message(glue("Writing State Senate variables to file {state_senate_file_name}..."))
state_senate_vars |> write_csv(state_senate_file_name)

message("Done.")

