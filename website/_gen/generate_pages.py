import argparse
import pandas as pd
import pathlib
from datetime import date
from pyprojroot import here

# Published ma-election-db dataset (same source the R loaders read).
MA_ELECTION_DB_URL = "https://bwbensonjr.github.io/ma-election-db/data/"

# District-name normalization, ported from R/district_utils.R::fix_district().
# Replacements are applied in order as plain-substring substitutions, so the
# two-digit ordinals must precede the single-digit ones (e.g. "10" before "1").
_DISTRICT_FIXES = [
    (" & ", " and "),
    ("10", "Tenth"),
    ("11", "Eleventh"),
    ("1", "First"),
    ("2", "Second"),
    ("3", "Third"),
    ("4", "Fourth"),
    ("5", "Fifth"),
    ("6", "Sixth"),
    ("7", "Seventh"),
    ("8", "Eighth"),
    ("9", "Ninth"),
]

def fix_district(name):
    s = str(name)
    for old, new in _DISTRICT_FIXES:
        s = s.replace(old, new)
    return s

def main():
    parser = create_arg_parser()
    args = parser.parse_args()
    if args.district and not args.office:
        parser.error("--district requires --office")
    districts = load_district_table()
    offices = districts["office"].unique()
    for office_name in offices:
        if args.office and (args.office != office_name):
            continue
        generate_office_page(office_name)
    for row in districts.itertuples(index=False):
        if args.office and (args.office != row.office):
            continue
        if args.district and (args.district != row.district):
            continue
        image_name = f"{district_slug(row.district)}.png"
        generate_district_page(
            row.office,
            row.district,
            row.summary,
            image_name,
            row.data_fingerprint,
        )

def load_district_table():
    """Build the per-district driver table from the published dataset.

    The district universe and summaries come from ma-election-db, and each row
    carries a data_fingerprint composed of the temporal keys that determine the
    page's rendered content. Embedding the fingerprint in the generated .qmd
    lets Quarto's `freeze: auto` re-render exactly the districts whose
    underlying data changed.
    """
    # Universe: the most recent PVI cycle -- one row per rendered district
    # across all four legislative offices.
    pvi = pd.read_csv(MA_ELECTION_DB_URL + "pvi/ma_district_pvi.csv.gz")
    pvi_year = int(pvi["pvi_year"].max())
    pvi = pvi[pvi["pvi_year"] == pvi_year].copy()
    pvi["district"] = pvi["district"].map(fix_district)

    # Summaries: most recent summary in effect as of today, per (office, district).
    summ = pd.read_csv(
        MA_ELECTION_DB_URL + "district_summaries.csv",
        parse_dates=["effective_date"],
    )
    summ = summ[summ["effective_date"] <= pd.Timestamp(date.today())]
    summ = (summ.sort_values("effective_date")
                .drop_duplicates(["office", "district"], keep="last"))
    summ["district"] = summ["district"].map(fix_district)

    # Latest election date per district -- the per-district change signal.
    elec = pd.read_csv(
        MA_ELECTION_DB_URL + "ma_general_election_summaries.csv.gz",
        usecols=["office", "district", "election_date"],
    )
    elec["district"] = elec["district"].map(fix_district)
    latest_elec = (elec.groupby(["office", "district"], as_index=False)["election_date"]
                       .max()
                       .rename(columns={"election_date": "latest_election_date"}))

    # Vintage keys that apply uniformly across the current cycle but still
    # belong in the fingerprint (a bump should re-render every page).
    demo = pd.read_csv(
        MA_ELECTION_DB_URL + "demographics/ma_district_demographics.csv.gz",
        usecols=["census_year"],
    )
    census_year = int(demo["census_year"].max())
    pdist = pd.read_csv(
        MA_ELECTION_DB_URL + "precinct/ma_precinct_district.csv.gz",
        usecols=["redistricting_year"],
    )
    redistricting_year = int(pdist["redistricting_year"].max())

    districts = (
        pvi[["office", "district"]]
        .merge(summ[["office", "district", "summary", "effective_date"]],
               on=["office", "district"], how="left")
        .merge(latest_elec, on=["office", "district"], how="left")
    )
    districts["summary"] = districts["summary"].fillna("")
    districts["data_fingerprint"] = districts.apply(
        lambda r: district_fingerprint(
            r, pvi_year, census_year, redistricting_year
        ),
        axis=1,
    )
    return districts

def district_fingerprint(row, pvi_year, census_year, redistricting_year):
    """Human-readable fingerprint of the inputs that drive a district page.

    A change to any of these values changes the generated .qmd, which busts
    Quarto's freeze and re-renders that district -- and the readable form means
    a git diff of the .qmd shows *why* it changed.
    """
    effective = row["effective_date"]
    summary_key = effective.date().isoformat() if pd.notna(effective) else "none"
    election_key = (row["latest_election_date"]
                    if pd.notna(row["latest_election_date"]) else "none")
    return (
        f"pvi={pvi_year} election={election_key} census={census_year} "
        f"redistricting={redistricting_year} summary={summary_key}"
    )

def local_file_path(file_name):
    file_path = f"{pathlib.Path(__file__).parent}/{file_name}"
    return file_path

def create_arg_parser():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--office",
        type=str,
        help="Only generate pages for the provided office"
    )
    parser.add_argument(
        "--district",
        type=str,
        help="Only generate pages for the provided district (requires --office)"
    )
    return parser

OFFICE_SLUG = {
    "State Representative": "state-rep",
    "State Senate": "state-senate",
    "Governor's Council": "gov-council",
    "U.S. House": "us-house",
}

OFFICE_DESCRIPTION = {
    "State Representative": "Interactive maps, demographics, and election history for all 160 Massachusetts State Representative districts.",
    "State Senate": "Interactive maps, demographics, and election history for all 40 Massachusetts State Senate districts.",
    "Governor's Council": "Interactive maps, demographics, and election history for all 8 Massachusetts Governor's Council districts.",
    "U.S. House": "Interactive maps, demographics, and election history for all 9 Massachusetts U.S. House congressional districts.",
}

def office_summary_file(office_name):
    file_name = here(f"website/districts/{OFFICE_SLUG[office_name]}/index.qmd")
    return file_name

def district_slug(district_name):
    slug = (district_name
            .lower()
            .replace(" ", "-")
            .replace("&", "and")
            .replace(",", ""))
    return slug

def district_file(office_name, district_name):
    file_name = here(
        "website/districts/"
        f"{OFFICE_SLUG[office_name]}/"
        f"{district_slug(district_name)}.qmd"
    )
    return file_name

def generate_office_page(office_name):
    output_file = office_summary_file(office_name)
    print(f"Generating office page {office_name} - {output_file}...")
    with open(here("website/_gen/office_page.qmd")) as f:
        template_str = f.read()
    file_contents = template_str % {
        "office_name": office_name,
        "description": OFFICE_DESCRIPTION[office_name],
    }
    with open(output_file, "w") as f:
        f.write(file_contents)

def generate_district_page(office_name, district_name, summary, image_name, data_fingerprint):
    output_file = district_file(office_name, district_name)
    print(f"Generating district page {office_name} - {district_name} - {output_file}...")
    with open(here("website/_gen/district_page.qmd")) as f:
        template_str = f.read()
    file_contents = (
        template_str % {
            "office_name": office_name,
            "district_name": district_name,
            "description": summary,
            "image_name": image_name,
            "data_fingerprint": data_fingerprint,
        }
    )
    with open(output_file, "w") as f:
        f.write(file_contents)

if __name__ == "__main__":
    main()
