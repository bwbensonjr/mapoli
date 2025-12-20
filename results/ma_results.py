import pandas as pd
import sys

RESULTS_URL = "http://electionstats.state.ma.us/elections/download/{election_id}/precincts_include:1"

def main():
    election_date = sys.argv[1]
    office = sys.argv[2]
    out_file = f"MA-{office}-{election_date}.csv"
    results = election_results(election_date, office)
    print(f"Writing {out_file}...")
    results.to_csv(out_file, index=False)
    print("Done.")

def election_results(election_date, office):
    elecs = pd.read_csv(
        "https://bwbensonjr.github.io/ma-election-db/"
        "data/ma_general_election_summaries.csv.gz"
    )
    matched_elecs = elecs[(elecs["election_date"] == election_date) &
                          (elecs["office"] == office)]
    result_list = []
    for ix, row in matched_elecs.iterrows():
        print(f"{row.office} - {row.district_display}: {row.election_id}")
        dist_results = read_election(row.election_id)
        dist_results["office"] = row.office
        dist_results["district"] = row.district
        result_list.append(dist_results)
    results = (pd.concat(result_list, ignore_index=True)
               .sort_values(["city_town", "ward", "precinct"]))
    return results
    
def read_election(election_id):
    results = (
        pd.read_csv(
            RESULTS_URL.format(election_id=election_id),
            thousands=",",
            dtype={"Ward": str, "Pct": str},
            skiprows=[1],
            skipfooter=1,
            engine="python",
        ).rename(
            columns={
                "City/Town": "city_town",
                "Ward": "ward",
                "Pct": "precinct",
            }
        )
    )
    tidy_results = pd.melt(
        results,
        id_vars=["city_town", "ward", "precinct"],
        var_name="receiver",
        value_name="votes",
    )
    return tidy_results

if __name__ == "__main__":
    main()
