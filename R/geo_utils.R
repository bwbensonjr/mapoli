# R/geo_utils.R
# Geographic and compass direction utilities for Massachusetts data

library(tidyverse)

#' Abbreviate compass directions in city/town names
#' @param name Character vector of names
#' @return Character vector with abbreviated compass directions
abbreviate_compass <- function(name) {
    str_replace_all(name,
                    c("North " = "N. ",
                      "East " = "E. ",
                      "South " = "S. ",
                      "West " = "W. "))
}

#' Expand abbreviated compass directions in city/town names
#' @param name Character vector of names
#' @return Character vector with full compass directions
unabbreviate_compass <- function(name) {
    str_replace_all(name,
                    fixed(c("N. " = "North ",
                            "E. " = "East ",
                            "S. " = "South ",
                            "W. " = "West ")))
}
