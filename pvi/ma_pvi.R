## Code for working on PVI data

library(tidyverse)

## Add Presidential 2016 and 2020 raw votes to City/Town PVI


ma_ct_votes <- read_csv("ma_precincts_districts_16_20_pres.csv") %>%
    group_by(`City/Town`) %>%
    summarize(across(where(is.numeric), sum))

ct_pvi <- read_csv("ma_city_town_pvi_2020.csv") %>%
    left_join(ma_ct_votes, by="City/Town")

## Overwrite existing file
ct_pvi %>%
    write_csv("ma_city_town_pvi_2020.csv")
