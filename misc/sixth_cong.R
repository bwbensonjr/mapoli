library(here)
source(here("website/_gen/legislative_info.R"))

prec_6th <- prec_dist |> filter(US_House == "Sixth")

ct_counties <-
    read_csv(here("demographics/data/ma_city_town_demographics.csv")) |>
    select(city_town, county)

ct_info <-
    read_sf(here("gis/geojson/city_town_2024.geojson")) |>
    as_tibble() |>
    select(city_town, type, county) |>
    mutate(type = case_when(
        (type == "C") ~ "City",
        (type == "T") ~ "Town"
    ))

prec_pop <-
    read_csv(here("demographics/data/ma_precinct_demographics.csv")) |>
    select(city_town, ward, precinct, total_population)

state_senate_num_precincts <-
    prec_dist |>
    group_by(State_Senate) |>
    summarize(num_precincts = n())

state_rep_num_precincts <-
    prec_dist |>
    group_by(State_Rep) |>
    summarize(num_precincts = n())

gov_council_num_precincts <-
    prec_dist |>
    group_by(Gov_Council) |>
    summarize(num_precincts = n())

prec_6th <- prec_dist |>
    left_join(prec_pop, by = c("city_town", "ward", "precinct")) |>
    filter(US_House == "Sixth")

ct_6th <- prec_6th |>
    left_join(city_town_num_precincts, by = "city_town") |>
    group_by(city_town) |>
    summarize(
        overlap = if_else(
            (first(num_precincts) == n()),
            "",
            str_c(n(), "/", first(num_precincts))
        ),
        dist_population = sum(total_population),
        .groups = "drop"
    ) |>
    left_join(ct_info, by = "city_town") |>
    arrange(county, city_town) |>
    select(city_town, overlap, type, county, dist_population)

state_senate_6th <- prec_6th |>
    left_join(state_senate_num_precincts, by = "State_Senate") |>
    group_by(State_Senate) |>
    summarize(
        overlap = if_else(
            (first(num_precincts) == n()),
            "",
            str_c(n(), "/", first(num_precincts))
        ),
        dist_population = sum(total_population),
        .groups = "drop"
    ) |>
    mutate(office = "State Senate") |>
    select(office, district=State_Senate, overlap, dist_population) |>
    left_join(
        legislative_district_info,
        by = c("office", "district")
    ) |>
    arrange(desc(dist_population))

state_rep_6th <- prec_6th |>
    left_join(state_rep_num_precincts, by = "State_Rep") |>
    group_by(State_Rep) |>
    summarize(
        overlap = if_else(
            (first(num_precincts) == n()),
            "",
            str_c(n(), "/", first(num_precincts))
        ),
        dist_population = sum(total_population),
        .groups = "drop"
    ) |>
    mutate(office = "State Representative") |>
    select(office, district=State_Rep, overlap, dist_population) |>
    left_join(
        legislative_district_info,
        by = c("office", "district")
    ) |>
    arrange(desc(dist_population))

gov_council_6th <- prec_6th |>
    left_join(gov_council_num_precincts, by = "Gov_Council") |>
    group_by(Gov_Council) |>
    summarize(
        overlap = if_else(
            (first(num_precincts) == n()),
            "",
            str_c(n(), "/", first(num_precincts))
        ),
        dist_population = sum(total_population),
        .groups = "drop"
    ) |>
    mutate(office = "Governor's Council") |>
    select(office, district=Gov_Council, overlap, dist_population) |>
    left_join(
        legislative_district_info,
        by = c("office", "district")
    ) |>
    arrange(desc(dist_population))

# ct_6th |> write_csv("sixth_cong_munis.csv")
# state_senate_6th |> write_csv("sixth_cong_state_senate.csv")
# state_rep_6th |> write_csv("sixth_cong_state_rep.csv")
# gov_council_6th |> write_csv("sixth_cong_gov_council.csv")
