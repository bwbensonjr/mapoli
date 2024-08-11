library(tidyverse)
library(lubridate)
library(rstanarm)

URL_BASE <- "https://bwbensonjr.github.io/ma-election-db/"
GEN_ELEC_FILE <- "data/ma_general_election_summaries_1990_2024.csv.gz"
GEN_ELECS_URL <- paste0(URL_BASE, GEN_ELEC_FILE)

START_DATE <- "2008-11-04"

pres_elec_dates <- c(
    "2008-11-04",
    "2012-11-06",
    "2016-11-08",
    "2020-11-03"
)

pvi_years <- tribble(
    ~election_year, ~pvi_year,
    2008, 2008,
    2009, 2008,
    2010, 2008,
    2011, 2008,
    2012, 2008,
    2013, 2012,
    2014, 2012,
    2015, 2012,
    2016, 2012,
    2017, 2016,
    2018, 2016,
    2019, 2016,
    2020, 2016,
    2021, 2022,
    2022, 2022,
    2023, 2022,
    2024, 2022)

leg_dist_pvi <- read_csv("../pvi/ma_state_leg_pvi_2008_2022.csv") %>%
    rename(district_display = district)

dist_name_changes <- c(
    " & " = " and ",
    "First " = "1st ",
    "Second " = "2nd ",
    "Third " = "3rd "
)

democratic_margin <- function(percent_dem, percent_gop, percent_third_party, percent_write_in) {
    if (is.na(percent_dem)) {
        -(percent_gop - max(percent_third_party,
                            percent_write_in,
                            na.rm=TRUE))
    } else {
        (percent_dem - max(percent_gop,
                           percent_third_party,
                           percent_write_in,
                           na.rm=TRUE))
    }
}

leg_elecs <- read_csv(GEN_ELECS_URL) %>%
    filter(election_date >= START_DATE,
           office %in% c("State Representative",
                         "State Senate"),
           num_candidates > 1) %>%
    mutate(election_year = year(election_date),
           district_display = str_replace_all(district_display,
                                              dist_name_changes),
           incumbent_status = case_when(
               is.na(party_incumbent) ~ "No_Incumbent",
               (party_incumbent == "Democratic") ~ "Dem_Incumbent",
               (party_incumbent == "Republican") ~ "GOP_Incumbent",
               (party_incumbent == "Unenrolled") ~ "GOP_Incumbent"
           ),
           dem_win = (party_winner == "Democratic")) %>%
    rowwise() %>%
    mutate(dem_margin = democratic_margin(percent_dem,
                                          percent_gop,
                                          percent_third_party,
                                          percent_write_in),
           pres_elec = (election_date %in% pres_elec_dates)) %>%
    ungroup() %>%
    left_join(pvi_years, by="election_year") %>%
    left_join(leg_dist_pvi, by=c("office",
                                 "district_display",
                                 "pvi_year"))

## leg_elecs %>%
##     write_csv("ma_leg_two_party_2008_2024.csv")
##
## leg_elecs <- read_csv("ma_leg_two_party_2008_2024.csv")

win_model <- stan_glm(dem_win ~ PVI_N + incumbent_status + pres_elec,
                      data=leg_elecs,
                      family=binomial(link="logit"))

margin_model <- stan_glm(dem_margin ~ PVI_N + incumbent_status + pres_elec,
                         data=leg_elecs,
                         family=gaussian(link="identity"))
