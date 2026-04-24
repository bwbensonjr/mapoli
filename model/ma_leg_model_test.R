library(tidyverse)
library(lubridate)
library(rstanarm)

SPLIT_DATES = c(
    "2016-11-08",
    "2018-11-06",
    "2020-11-03",
    "2022-11-08"
)


leg_elecs <- read_csv("ma_leg_two_party_2008_2024.csv")

train_test_results <- function(df, split_date) {
    train_df <- df %>% filter(election_date < split_date)
    test_df <- df %>% filter(election_date >= split_date)
    
    margin_model <- stan_glm(
        dem_margin ~ PVI_N + incumbent_status + pres_elec,
        data=train_df,
        family=gaussian(link="identity"),
        refresh=0
    )
    test_margins <- posterior_predict(margin_model, test_df)
    pred_dem_margin <- colMeans(test_margins)
    test_df %>%
        mutate(pred_dem_margin = pred_dem_margin,
               split_date = split_date)
}

cat_test <- read_csv("catboost_test_results.csv") %>%
    mutate(error = dem_margin - pred_dem_margin)

error_model_full <- lm(error ~ PVI_N + incumbent_status + pres_elec + election_year + num_candidates + is_special + election_date + party_third_party + city_town_dem + city_town_gop + city_town_incumbent + district + office + party_write_in + city_town_write_in, data=cat_test)

error_model_small <- lm(error ~ pres_elec + election_year + is_special + election_date, data=cat_test)
error_model_small_1 <- lm(error ~ pres_elec + election_year + is_special, data=cat_test)

err_model_2 <- lm(error ~ pred_dem_margin, data=cat_test)

err_model_3 <- stan_glm(error ~ pred_dem_margin + PVI_N + incumbent_status + pres_elec, data=cat_test, family=gaussian(link="identity"))
