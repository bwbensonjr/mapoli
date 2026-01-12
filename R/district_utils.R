# R/district_utils.R
# District name formatting and conversion utilities

library(tidyverse)

#' Convert word ordinals to numeric format
#' @param name District name with word ordinals
#' @return District name with numeric ordinals (e.g., "1st Bristol")
word_to_numeric_ordinal <- function(name) {
    ordinal_map <- c(
        "First" = "1st", "Second" = "2nd", "Third" = "3rd", "Fourth" = "4th",
        "Fifth" = "5th", "Sixth" = "6th", "Seventh" = "7th", "Eighth" = "8th",
        "Ninth" = "9th", "Tenth" = "10th", "Eleventh" = "11th", "Twelfth" = "12th",
        "Thirteenth" = "13th", "Fourteenth" = "14th", "Fifteenth" = "15th",
        "Sixteenth" = "16th", "Seventeenth" = "17th", "Eighteenth" = "18th",
        "Nineteenth" = "19th", "Twentieth" = "20th", "Twenty-First" = "21st",
        "Twenty-Second" = "22nd", "Twenty-Third" = "23rd", "Twenty-Fourth" = "24th",
        "Twenty-Fifth" = "25th", "Twenty-Sixth" = "26th", "Twenty-Seventh" = "27th",
        "Twenty-Eighth" = "28th", "Twenty-Ninth" = "29th", "Thirtieth" = "30th",
        "Thirty-First" = "31st", "Thirty-Second" = "32nd", "Thirty-Third" = "33rd",
        "Thirty-Fourth" = "34th", "Thirty-Fifth" = "35th", "Thirty-Sixth" = "36th",
        "Thirty-Seventh" = "37th"
    )
    str_replace_all(name, ordinal_map)
}

#' Convert numeric ordinals to word format
#' @param name District name with numeric ordinals
#' @return District name with word ordinals (e.g., "First Bristol")
numeric_to_word_ordinal <- function(name) {
    ordinal_map <- c(
        "1st" = "First", "2nd" = "Second", "3rd" = "Third", "4th" = "Fourth",
        "5th" = "Fifth", "6th" = "Sixth", "7th" = "Seventh", "8th" = "Eighth",
        "9th" = "Ninth", "10th" = "Tenth", "11th" = "Eleventh", "12th" = "Twelfth",
        "13th" = "Thirteenth", "14th" = "Fourteenth", "15th" = "Fifteenth",
        "16th" = "Sixteenth", "17th" = "Seventeenth", "18th" = "Eighteenth",
        "19th" = "Nineteenth", "20th" = "Twentieth", "21st" = "Twenty-First",
        "22nd" = "Twenty-Second", "23rd" = "Twenty-Third", "24th" = "Twenty-Fourth",
        "25th" = "Twenty-Fifth", "26th" = "Twenty-Sixth", "27th" = "Twenty-Seventh",
        "28th" = "Twenty-Eighth", "29th" = "Twenty-Ninth", "30th" = "Thirtieth",
        "31st" = "Thirty-First", "32nd" = "Thirty-Second", "33rd" = "Thirty-Third",
        "34th" = "Thirty-Fourth", "35th" = "Thirty-Fifth", "36th" = "Thirty-Sixth",
        "37th" = "Thirty-Seventh"
    )
    str_replace_all(name, ordinal_map)
}

#' Normalize ampersand to "and" for consistency
#' @param name District name
#' @return District name with " & " replaced by " and "
normalize_ampersand <- function(name) {
    str_replace_all(name, " & ", " and ")
}

#' Fix district names from election data format
#' Converts numeric district identifiers to word ordinals
#' @param district_name Raw district name
#' @return Standardized district name
fix_district <- function(district_name) {
    str_replace_all(
        district_name,
        c(" & " = " and ",
          "10" = "Tenth",
          "11" = "Eleventh",
          "1" = "First",
          "2" = "Second",
          "3" = "Third",
          "4" = "Fourth",
          "5" = "Fifth",
          "6" = "Sixth",
          "7" = "Seventh",
          "8" = "Eighth",
          "9" = "Ninth")
    )
}

#' Get URL-friendly slug for office
#' @param office_name Full office name
#' @return URL slug
office_slug <- function(office_name) {
    case_when(
        (office_name == "State Representative") ~ "state-rep",
        (office_name == "State Senate") ~ "state-senate",
        (office_name == "Governor's Council") ~ "gov-council",
        (office_name == "U.S. House") ~ "us-house"
    )
}

#' Get URL-friendly slug for district
#' @param district_name Full district name
#' @return URL slug
district_slug <- function(district_name) {
    str_replace_all(
        str_to_lower(district_name),
        c(" " = "-",
          "&" = "and",
          "," = "",
          "1" = "first",
          "2" = "second",
          "3" = "third",
          "4" = "fourth",
          "5" = "fifth",
          "6" = "sixth",
          "7" = "seventh",
          "8" = "eighth",
          "9" = "ninth")
    )
}

#' Get data column name for office
#' @param office_name Full office name
#' @return Column name used in data frames
office_column <- function(office_name) {
    case_when(
        (office_name == "State Representative") ~ "State_Rep",
        (office_name == "State Senate") ~ "State_Senate",
        (office_name == "Governor's Council") ~ "Gov_Council",
        (office_name == "U.S. House") ~ "US_House"
    )
}
