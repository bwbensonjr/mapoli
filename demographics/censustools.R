library(tidyverse)
library(tidycensus)
library(sf)
library(tigris)
library(e1071)
library(here)

## ACS 5-year endpoint year (e.g., 2024 = 2020-2024 ACS)
acs_year <- 2024

census_vars <- read_csv(here("demographics/census_vars.csv"))

census_query <- function(geography, census_vars, geometry=FALSE, state=NULL) {
    get_acs(geography=geography,
            variables=census_vars$variable,
            geometry=geometry,
            year=acs_year,
            sumfile="cd118",
            state=state) %>%
        left_join(census_vars, by="variable") %>%
        pivot_wider(id_cols=c("GEOID", "NAME"),
                    names_from="var_name",
                    values_from="estimate") %>%
        add_calculated_factors()
}

census_query_nf <- function(geography, census_vars, geometry=FALSE, state=NULL) {
    get_acs(geography=geography,
            variables=census_vars$variable,
            geometry=geometry,
            year=acs_year,
            state=state) %>%
        left_join(census_vars, by="variable") %>%
        pivot_wider(id_cols=c("GEOID", "NAME"),
                    names_from="var_name",
                    values_from="estimate")
}    

add_calculated_factors <- function(df) {
    df %>% mutate(gender_female_pct = gender_female / total_population,
                  below_poverty_pct = below_poverty_level / poverty_total,
                  ed_college_degree = ed_bachelors + ed_masters + ed_professional + ed_doctorate,
                  ed_college_degree_pct = ed_college_degree / total_population,
                  ed_some_college = ed_college_lt_1 + ed_college_gt_1 + ed_associates + ed_college_degree,
                  ed_some_college_pct = ed_some_college / total_population,
                  race_minority = race_black + race_native_american + race_asian + race_hawaiian + race_other + race_multiracial + race_hispanic,
                  race_minority_pct = race_minority / total_population,
                  race_white_pct = race_white / total_population,
                  race_black_pct = race_black / total_population,
                  race_asian_pct = race_asian / total_population,
                  race_hispanic_pct = race_hispanic / total_population,
                  race_native_pct = race_native_american / total_population,
                  poverty_pct = below_poverty_level / poverty_total,
                  vote_male_eligible = vote_male_native_18_plus + vote_male_naturalized_18_plus,
                  vote_female_eligible = vote_female_native_18_plus + vote_female_naturalized_18_plus,
                  vote_eligible = vote_male_eligible + vote_female_eligible,
                  vote_female_pct = vote_female_eligible / vote_eligible,
                  wwc_pct = (white_nh_male_lt_high_school + white_nh_male_high_school_grad + white_nh_male_some_college +
                             white_nh_female_lt_high_school + white_nh_female_high_school_grad + white_nh_female_some_college) / total_population,
                  white_college_pct = (white_nh_male_bachelors_or_gt + white_nh_female_bachelors_or_gt) / total_population)
}

## Get 2-character state abbreviations to be used in
## add_cong_dist_info
state_codes <- tidycensus::fips_codes %>%
    group_by(state) %>%
    select(state_fips = state_code, state, state_name) %>%
    filter(row_number() == 1) %>%
    filter(state_fips < "60") %>%
    ungroup() %>%
    arrange(state_fips)

## Add a uniform congression district name (e.g., cong_dist = "AZ-01")
add_cong_dist_info <- function(df) {
    df %>%
        mutate(state_fips = substr(GEOID, 1, 2),
               dist_num = if_else(substr(GEOID, 3, 4) == "00",
                                  "AL",
                                  substr(GEOID, 3, 4))) %>%
        left_join(state_codes, by="state_fips") %>%
        mutate(cong_dist = paste0(state, "-", dist_num)) %>%
        filter(dist_num != "98") %>%
        relocate(GEOID, NAME, state, state_name, state_fips,
                 dist_num, cong_dist)
}

## Geometric characteristics like area and centroid latitude and longitude
us_cong_geom <- as_tibble(congressional_districts(cb=TRUE, class="sf")) %>%
    mutate(center = (st_transform(geometry, 29101) %>%
                     st_centroid() %>%
                     st_transform("+proj=longlat +ellps=GRS80 +no_defs")),
           center_longitude = st_coordinates(center)[,1],
           center_latitude = st_coordinates(center)[,2],
           land_area = ALAND / 2589988, # convert km^2 to mi^2
           water_area = AWATER / 2589988) %>%
    select(GEOID, land_area, water_area, center_latitude, center_longitude)

us_cong_geom %>% write_csv(here("demographics/us_congress_geom_stats.csv"))
# us_cong_geom <- read_csv(here("demographics/us_congress_geom_stats.csv"))

## Election results for PVI
## us_cong_pvi <- read_csv("pres_results_by_congressional_district_08_12_16.csv") %>%
##     mutate(cong_dist = CD,
##            PVI_N_12 = (((Obama_12 + Obama_08)/((Obama_12 + Obama_08) + (Romney_12 + McCain_08))) - 0.528351) * 100,
##            dem_margin_12 = (Obama_12 - Romney_12)/100,
##            dem_margin_16 = (Clinton_16 - Trump_16)/100) %>%
##     select(cong_dist, PVI_N, PVI, dem_margin_16, dem_margin_12, PVI_N_12)

## Pre-calculated congression district density
## us_cong_urbanicity <- read_csv("citylab_cdi.csv")
## Pre-calculated religious percentages
## us_cong_religion <- read_csv("religion_by_cd_2017.csv")

us_cong <- census_query("congressional district", census_vars) %>%
    filter(substr(GEOID, 3, 4) != "ZZ") %>%
    add_cong_dist_info() %>%
    ## left_join(us_cong_pvi, by="cong_dist") %>%
    ## left_join(us_cong_urbanicity, by="cong_dist") %>%
    ## left_join(us_cong_religion, by="cong_dist") %>%
    left_join(us_cong_geom, by="GEOID") %>%
    mutate(pop_density = total_population / land_area)

write_csv(us_cong, here("demographics/us_congress_demographics.csv"))

us_states_geom <- as_tibble(states(cb=TRUE, class="sf")) %>%
    mutate(center = (st_transform(geometry, 29101) %>%
                     st_centroid() %>%
                     st_transform("+proj=longlat +ellps=GRS80 +no_defs")),
           center_longitude = st_coordinates(center)[,1],
           center_latitude = st_coordinates(center)[,2],
           land_area = ALAND / 2589988, # convert km^2 to mi^2
           water_area = AWATER / 2589988) %>%
    arrange(GEOID) %>%
    filter(GEOID < "60") %>%
    select(state_fips = GEOID,
           state = STUSPS,
           # state_name=NAME,
           land_area,
           water_area,
           center_latitude,
           center_longitude)

write_csv(us_states_geom, here("demographics/us_states_geom_stats.csv"))

## us_states_geom <- read_csv(here("demographics/us_states_geom_stats.csv")) %>%
##     select(-c(state_name))

## us_states_religion <- read_csv(here("demographics/us_states_religion_stats.csv")) %>%
##     select(-c(state, state_name))

## us_states_density <- read_csv(here("demographics/us_states_density_stats.csv")) %>%
##     select(-c(state, state_name))

## us_states_pvi <- read_csv(here("demographics/us_states_pvi_2016.csv")) %>%
##     mutate(dem_margin_12 = (Obama_12_Pct - Romney_12_Pct)/100,
##            dem_margin_16 = (Clinton_16_Pct - Trump_16_Pct)/100) %>%
##     select(state, PVI_N, PVI, dem_margin_16, dem_margin_12, PVI_N_12)

us_states <- census_query("state", census_vars) %>%
    rename(state_fips = GEOID, state_name = NAME) %>%
    filter(state_fips < "60") %>%
    left_join(us_states_geom, by="state_fips") %>%
    ## left_join(us_states_religion, by="state_fips") %>%
    ## left_join(us_states_density, by="state_fips") %>%
    ## left_join(us_states_pvi, by="state") %>%
    mutate(pop_density = total_population / land_area)

write_csv(us_states, here("demographics/us_state_demographics.csv"))

### Density calculations

### MA
ma_tract_hh <- get_acs(geography="tract",
                       variables=c("NAME", "DP02_0001E"),
                       year=acs_year,
                       state=25) %>%
    rename(total_households = estimate) %>%
    select(-c(variable, moe))

ma_tract_geom <- as_tibble(tracts(25, class="sf")) %>%
    mutate(area = ((ALAND + AWATER)/2.59e+6))

ma_tract_density <- ma_tract_hh %>%
    left_join(ma_tract_geom %>% select(GEOID, ALAND, AWATER, area, geometry), by="GEOID") %>%
    mutate(hh_per_sq_mi = as.double(total_households / area),
           density_type = case_when(hh_per_sq_mi < 102 ~ "very low density",
                                    hh_per_sq_mi < 800 ~ "low density",
                                    hh_per_sq_mi < 2123 ~ "medium density",
                                    TRUE ~ "high density"))
## State density

state_density <- function(state_fips) {
    tract_households <- get_acs(geography="tract", variables=c("NAME", "DP02_0001E"), state=state_fips) %>%
        rename(total_households = estimate) %>%
        select(-c(variable, moe))
    tract_geom <- as_tibble(tracts(state_fips, cb=TRUE, class="sf")) %>%
        mutate(area = (st_area(geometry)/2.59e+6))
    tract_density <- tract_households %>%
        inner_join(tract_geom %>% select(GEOID, ALAND, AWATER, area), by="GEOID") %>%
        mutate(hh_per_sq_mi = as.double(total_households / density),
               area_type = case_when(hh_per_sq_mi < 102 ~ "density_very_low",
                                        hh_per_sq_mi < 800 ~ "density_low",
                                        hh_per_sq_mi < 2123 ~ "density_medium",
                                        TRUE ~ "density_high")) %>%
        mutate(density_type = factor(density_type, levels=c("density_very_low", "density_low", "density_medium", "density_high")))
    tract_pcts <- tract_density %>%
        count(density_type, .drop=FALSE) %>%
        mutate(state_fips = state_fips,
               pct = n/sum(n)) %>%
        pivot_wider(id_cols="state_fips", names_from="density_type", values_from="pct") %>%
        select(state_fips, density_very_low, density_low, density_medium, density_high)
    tract_pcts
}

state_densities <- state_codes %>%
    pull(state_fips) %>%
    map_dfr(state_density) %>%
    right_join(state_codes, by="state_fips")

state_densities %>% select(state_fips, state, state_name, density_very_low, density_low, density_medium, density_high) %>%
    write_csv(here("demographics/us_states_density_stats.csv"))

## County density

square_meters_per_square_mile = 2.59e+6

state_county_density <- function(state_fips) {
    tract_households <- get_acs(geography="tract", variables=c("NAME", "DP02_0001E"), state=state_fips) %>%
        rename(total_households = estimate) %>%
        select(-c(variable, moe)) %>%
        mutate(state_fips = str_sub(GEOID, 1, 2),
               county_fips = str_sub(GEOID, 3, 5),
               county_geoid = str_sub(GEOID, 1, 5))
    tract_geom <- as_tibble(tracts(state_fips, cb=TRUE, class="sf")) %>%
        mutate(area = (st_area(geometry)/square_meters_per_square_mile))
    tract_density <- tract_households %>%
        inner_join(tract_geom %>% select(GEOID, ALAND, AWATER, area), by="GEOID") %>%
        mutate(hh_per_sq_mi = as.double(total_households / area),
               density_type = case_when(hh_per_sq_mi < 102 ~ "density_very_low",
                                        hh_per_sq_mi < 800 ~ "density_low",
                                        hh_per_sq_mi < 2123 ~ "density_medium",
                                        TRUE ~ "density_high")) %>%
        mutate(density_type = factor(density_type, levels=c("density_very_low", "density_low", "density_medium", "density_high")))
    county_pcts <- tract_density %>%
        group_by(county_geoid) %>%
        count(density_type, .drop=FALSE) %>%
        mutate(pct = n/sum(n)) %>%
        pivot_wider(id_cols="county_geoid", names_from="density_type", values_from="pct") %>%
        ungroup()
    county_pcts
}

## GA Counties

ga_county_density <- state_county_density(13)
ga_county_religion <- read_csv(here("demographics/arda_religion/us_counties_religion_stats.csv"),
                               col_types=cols(fips = col_character())) %>%
    filter(stabbr == "GA") %>%
    select(county_geoid = fips,
           rel_evangel_pct,
           rel_black_prot_pct,
           rel_mainline_pct,
           rel_catholic_pct,
           rel_orthodox_pct,
           rel_other_pct,
           rel_unclaimed_pct)
ga_counties <- census_query("county", census_vars, state="GA") %>%
    rename(county_geoid = GEOID) %>%
    left_join(ga_county_religion, by="county_geoid") %>%
    left_join(ga_county_density, by="county_geoid") %>%
    mutate(county = str_replace(NAME, " County, Georgia", ""))

write_csv(ga_counties, here("demographics/ga_county_demographics.csv"))

## MA Cities and Towns

ma_town_geom <- as_tibble(county_subdivisions(state="25", cb=TRUE, class="sf")) %>%
    mutate(center = (st_transform(geometry, 29101) %>%
                     st_centroid() %>%
                     st_transform("+proj=longlat +ellps=GRS80 +no_defs")),
           center_longitude = st_coordinates(center)[,1],
           center_latitude = st_coordinates(center)[,2],
           land_area = ALAND / 2589988, # convert km^2 to mi^2
           water_area = AWATER / 2589988) %>%
    arrange(GEOID) %>%
    mutate(city_town = str_replace(NAME, " Town", "")) %>%
    select(city_town_fips = GEOID,
           city_town,
           state_fips = STATEFP,
           land_area,
           water_area,
           center_latitude,
           center_longitude)

abbreviate_compass <- function(name) {
    str_replace_all(name,
                    c("North " = "N. ",
                      "East " = "E. ",
                      "South " = "S. ",
                      "West " = "W. "))
}

unabbreviate_compass <- function(name) {
    str_replace_all(name,
                    fixed(c("N. " = "North ",
                            "E. " = "East ",
                            "S. " = "South ",
                            "W. " = "West ")))
}

## No longer needed
##    mutate(city_town_fips = str_replace(city_town_fips, "2502155955", "2502156000")) %>%
##    mutate(city_town_fips = str_replace(city_town_fips, "2502308085", "2502308130")) %>%

ma_towns <- census_query("county subdivision",
                         census_vars,
                         state="25") %>%
    filter(total_population > 0) %>%
    rename(city_town_fips = GEOID) %>%
    inner_join(ma_town_geom, by="city_town_fips") %>%
    mutate(pop_density = total_population / land_area,
           city_town_abbr = abbreviate_compass(city_town)) %>%
    select(-c(NAME, state_fips)) %>%
    relocate(city_town_fips,
             city_town,
             city_town_abbr,
             total_population,
             pop_density,
             land_area,
             water_area,
             median_age,
             median_family_income,
             wwc_pct,
             white_college_pct,
             race_white_pct,
             race_minority_pct,
             race_black_pct,
             race_hispanic_pct,
             race_asian_pct,
             below_poverty_pct,
             center_latitude,
             center_longitude)

# write_csv(ma_towns, here("demographics/ma_city_town_demographics_2020.csv"))

tract_to_town <- read_csv(here("demographics/geocorr2022_2217308962.csv"), comment="#") %>%
    mutate(tract_fips = str_c(county, str_remove(tract, fixed("."))),
           city_town_fips = str_c(county, cousub20)) %>%
    select(tract_fips, city_town_fips)

## write_csv(tract_to_town, here("demographics/ma_tract_fips_to_city_town.csv"))


ma_town_density_calc <- function() {
    tract_households <- get_acs(geography="tract", variables=c("NAME", "DP02_0001E"), state="25") %>%
        rename(total_households = estimate) %>%
        select(-c(variable, moe))
    tract_geom <- as_tibble(tracts("25", cb=TRUE, class="sf")) %>%
        mutate(area = (st_area(geometry)/2.59e+6))
    tract_to_town <- read_csv(here("demographics/ma_tract_fips_to_city_town.csv"),
                              col_types=list(.default = col_character())) %>%
        rename(GEOID = tract_fips)
    tract_density <- tract_households %>%
        inner_join(tract_geom %>% select(GEOID, ALAND, AWATER, area), by="GEOID") %>%
        mutate(hh_per_sq_mi = as.double(total_households / area),
               density_type = case_when(hh_per_sq_mi < 102 ~ "density_very_low",
                                        hh_per_sq_mi < 800 ~ "density_low",
                                        hh_per_sq_mi < 2123 ~ "density_medium",
                                        TRUE ~ "density_high")) %>%
        mutate(density_type = factor(density_type, levels=c("density_very_low",
                                                            "density_low",
                                                            "density_medium",
                                                            "density_high"))) %>%
        left_join(tract_to_town, by="GEOID") %>%
        filter(!is.na(city_town_fips))
    city_town_density <- tract_density %>%
        group_by(city_town_fips) %>%
        count(density_type) %>%
        mutate(pct = n/sum(n)) %>%
        pivot_wider(id_cols="city_town_fips",
                    names_from="density_type",
                    values_from="pct",
                    values_fill=0) %>%
        ungroup()
    city_town_density
}

ma_city_town_density <- ma_town_density_calc()

ma_towns_density_pvi <- ma_towns %>%
    left_join(ma_city_town_density, by="city_town_fips") %>%
    left_join((read_csv(here("demographics/ma_city_town_pvi_2020.csv")) %>% rename(city_town_abbr = `City/Town`)),
              by="city_town_abbr") %>%
    relocate(city_town_fips,
             city_town,
             PVI,
             PVI_N,
             total_population)

## write_csv(ma_towns_density_pvi, here("demographics/ma_city_town_demographics_pvi_2020.csv"))

## MA House Districts

ma_house_geom <- as_tibble(state_legislative_districts(state="25",
                                                       house="lower",
                                                       cb=TRUE,
                                                       class="sf")) %>%
    filter(SLDLST != "ZZZ") %>%
    mutate(center = (st_transform(geometry, 29101) %>%
                     st_centroid() %>%
                     st_transform("+proj=longlat +ellps=GRS80 +no_defs")),
           center_longitude = st_coordinates(center)[,1],
           center_latitude = st_coordinates(center)[,2],
           land_area = ALAND / 2589988, # convert km^2 to mi^2
           water_area = AWATER / 2589988) %>%
    arrange(GEOID) %>%
    rename(district = NAME) %>%
    mutate(office = "State Rep") %>%
    select(state_fips = STATEFP,
           district,
           office,
           state_rep_fips = GEOID,
           land_area,
           water_area,
           center_latitude,
           center_longitude)

ma_sr_tracts <- read_csv(here("demographics/ma_state_rep_tracts.csv")) %>%
    mutate(GEOID = str_c(state_fips, county_fips, tract_fips)) %>%
    select(GEOID, state_rep_fips)

ma_lower_house_density <- function() {
    tract_households <- get_acs(geography="tract", variables=c("NAME", "DP02_0001E"), state="25") %>%
        rename(total_households = estimate) %>%
        select(-c(variable, moe))
    tract_geom <- as_tibble(tracts("25", cb=TRUE, class="sf")) %>%
        mutate(area = (st_area(geometry)/2.59e+6))
    tract_density <- tract_households %>%
        inner_join(tract_geom %>% select(GEOID, ALAND, AWATER, area), by="GEOID") %>%
        mutate(hh_per_sq_mi = as.double(total_households / area),
               density_type = case_when(hh_per_sq_mi < 102 ~ "density_very_low",
                                        hh_per_sq_mi < 800 ~ "density_low",
                                        hh_per_sq_mi < 2123 ~ "density_medium",
                                        TRUE ~ "density_high")) %>%
        mutate(density_type = factor(density_type, levels=c("density_very_low", "density_low", "density_medium", "density_high")))
    sr_pcts <- tract_density %>%
        right_join(ma_sr_tracts, by="GEOID") %>%
        group_by(state_rep_fips) %>%
        count(density_type, .drop=FALSE) %>%
        mutate(state_rep_fips = str_c("25", state_rep_fips),
               pct = n/sum(n)) %>%
        pivot_wider(id_cols="state_rep_fips", names_from="density_type", values_from="pct") %>%
        select(state_rep_fips, density_very_low, density_low, density_medium, density_high) %>%
        ungroup()
    sr_pcts
}

ma_house_density <- ma_lower_house_density()

cmeans6 <- ma_house_density %>%
    select(density_very_low,
           density_low,
           density_medium,
           density_high) %>%
    as.matrix() %>%
    cmeans(6, iter.max=1000)

cluster_names <- cmeans6$centers %>% 
    as_tibble() %>% 
    rownames_to_column(var = "density_cluster_number") %>%
    mutate(density_cluster_number = as.integer(density_cluster_number)) %>%
    arrange(density_high) %>%
    mutate(density_cluster = c("Pure suburban", "Rural mix", "Rural-suburban mix",
                               "Dense suburban", "Urban-suburban mix", "Pure urban")) %>%
    select(density_cluster_number, density_cluster) %>%
    arrange(density_cluster_number)

ma_house_density_cl <- ma_house_density %>%
    mutate(density_cluster_number = cmeans6$cluster) %>%
    left_join(cluster_names, by="density_cluster_number") %>%
    select(-density_cluster_number)

ma_house_pvi <- read_csv(here("demographics/ma_state_rep_dist_pvi_2016.csv")) %>%
    rename(district = `State Rep`)

ma_house_inc <- read_csv(here("demographics/ma_state_rep_incumbents_2018.csv")) %>%
    select(-office)

ma_house <- census_query("state legislative district (lower chamber)", census_vars, state="25") %>%
    filter(total_population > 0) %>%
    rename(state_rep_fips = GEOID) %>%
    select(-NAME) %>%
    inner_join(ma_house_geom, by="state_rep_fips") %>%
    mutate(pop_density = total_population / land_area) %>%
    inner_join(ma_house_density_cl, by="state_rep_fips") %>%
    inner_join(ma_house_pvi, by="district") %>%
    inner_join(ma_house_inc, by="district")

write_csv(ma_house, here("demographics/ma_state_rep_demographics.csv"))

## New

ma_towns <- county_subdivisions(state="25", cb=TRUE, class="sf") %>%
    mutate(city_town = str_replace(NAME, " Town", ""))

ma_tracts <- census_query_nf("tract",
                             cv_tot_pop,
                             geometry=TRUE,
                             state=25)

ma_tracts <- get_acs(geography="tract",
                     variables=cv_tot_pop$varible,
                     geometry=TRUE,
                     year=acs_year,
                     state=25)
