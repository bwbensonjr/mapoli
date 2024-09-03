library(tidyverse)

pct_dist_pres <- read_csv("ma_precincts_districts_pres_2022.csv")

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

pvi_string <- function(pvi_n) {
    case_when(
        pvi_n <= -0.5 ~ str_c("R+", round(abs(pvi_n))),
        pvi_n >= 0.5 ~ str_c("D+", round(pvi_n)),
        TRUE ~ "EVEN",
    )
}

US_PVI <- dem_percent(
    US_Biden_20,
    US_Trump_20,
    US_Clinton_16,
    US_Trump_16
)

add_pvi_20 <- function(df) {
    df %>%
        mutate(PVI_N = ((dem_percent(Biden_20,
                                     Trump_20,
                                     Clinton_16,
                                     Trump_16) - US_PVI_2020) * 100),
               PVI = pvi_string(PVI_N))
}

