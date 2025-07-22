import argparse
import pandas as pd
import pathlib

def main():
    parser = create_arg_parser()
    args = parser.parse_args()
    if args.district and not args.office:
        parser.error("--district requires --office")
    df = pd.read_csv("../districts/ma_legislative_district_info.csv")
    offices = df["office"].unique()
    for office_name in offices:
        if args.office and (args.office != office_name):
            continue
        generate_office_page(office_name)
    districts = df[["office", "district"]].values
    for office_name, district_name in districts:
        if args.office and (args.office != office_name):
            continue
        if args.district and (args.district != district_name):
            continue
        generate_district_page(office_name, district_name)

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

def office_summary_file(office_name):
    file_name = f"districts/{OFFICE_SLUG[office_name]}/index.qmd"
    return file_name

def district_slug(district_name):
    slug = (district_name
            .lower()
            .replace(" ", "-")
            .replace("&", "and")
            .replace(",", ""))
    return slug

def district_file(office_name, district_name):
    file_name = (
        "districts/"
        f"{OFFICE_SLUG[office_name]}/"
        f"{district_slug(district_name)}.qmd"
    )
    return file_name

def generate_office_page(office_name):
    output_file = office_summary_file(office_name)
    print(f"Generating office page {office_name} - {output_file}...")
    with open(local_file_path("office_page.qmd")) as f:
        template_str = f.read()
    file_contents = template_str % {"office_name": office_name}
    with open(output_file, "w") as f:
        f.write(file_contents)

def generate_district_page(office_name, district_name):
    output_file = district_file(office_name, district_name)
    print(f"Generating district page {office_name} - {district_name} - {output_file}...")
    with open(local_file_path("district_page.qmd")) as f:
        template_str = f.read()
    file_contents = (
        template_str % {
            "office_name": office_name,
            "district_name": district_name,
        }
    )
    with open(output_file, "w") as f:
        f.write(file_contents)
    
if __name__ == "__main__":
    main()
