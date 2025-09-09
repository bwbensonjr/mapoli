import argparse
import pandas as pd
from pyprojroot import here

def main():
    parser = create_arg_parser()
    args = parser.parse_args()
    prec_dist = pd.read_csv(here("pvi/ma_precincts_districts_pres_2024.csv"))

def city_town_slug(city_town_name):
    slug = (city_town_name
            .lower()
            .replace(" ", "-"))
    return slug

    
def create_arg_parser():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--city-town",
        type=str,
        help="Only generate pages for the provided city or town"
    )
    return parser
    
