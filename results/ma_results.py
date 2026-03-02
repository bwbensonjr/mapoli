import pandas as pd
import sys

RESULTS_URL = "http://electionstats.state.ma.us/elections/download/{election_id}/precincts_include:1"

OFFICE_SLUG = {
    "State Representative": "state-rep",
    "State Senate": "state-senate",
    "U.S. House": "us-house",
    "Governor's Council": "gov-council",
    "U.S. Senate": "us-senate",
    "Governor": "governor",
    "President": "president",
    
}

def main():
    election_date = sys.argv[1]
    office = sys.argv[2]
    if (len(sys.argv) == 4) and (sys.argv[3] == "Primaries"):
        stage = "Primaries"
        stage_slug = "-primary"
    else:
        stage = "General"
        stage_slug = ""
    office_slug = OFFICE_SLUG[office]
    out_file = f"ma-{office_slug}-{election_date}{stage_slug}.csv"
    results = election_results(election_date, office, stage)
    print(f"Writing {out_file}...")
    results.to_csv(out_file, index=False)
    print("Done.")

def election_results(election_date, office, stage="General"):
    if stage == "Primaries":
        elecs = pd.read_csv(
            "https://bwbensonjr.github.io/ma-election-db/"
            "data/ma_primary_election_summaries.csv.gz"
        )
        cands = pd.read_csv(
            "https://bwbensonjr.github.io/ma-election-db/"
            "data/ma_primary_election_candidates.csv.gz",
            dtype={"candidate_id": "Int64"},
        )
    else:
        elecs = pd.read_csv(
            "https://bwbensonjr.github.io/ma-election-db/"
            "data/ma_general_election_summaries.csv.gz"
        )
        cands = pd.read_csv(
            "https://bwbensonjr.github.io/ma-election-db/"
            "data/ma_general_election_candidates.csv.gz",
            dtype={"candidate_id": "Int64"},
        )
    matched_elecs = elecs[(elecs["election_date"] == election_date) &
                          (elecs["office"] == office)]
    matched_cands = cands[(cands["election_date"] == election_date) &
                          (cands["office"] == office)][[
                              "election_id",
                              "candidate_id",
                              "name",
                          ]]
    result_list = []
    for ix, row in matched_elecs.iterrows():
        print(f"{row.office} - {row.district_display}: {row.election_id}")
        dist_results = read_election(row.election_id)
        dist_results["election_id"] = row.election_id
        dist_results["office"] = row.office
        dist_results["district"] = row.district
        results_w_id = dist_results.merge(
            matched_cands,
            on=["election_id", "name"],
            how="left",
        )[[
            "election_id",
            "office",
            "district",
            "candidate_id",
            "name",
            "city_town",
            "ward",
            "precinct",
            "votes",
        ]]
        result_list.append(results_w_id)
    results = pd.concat(result_list, ignore_index=True)
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
                "All Others": "all_others",
                "Blanks": "blanks",
                "Total Votes Cast": "total_votes",
            }
        )
    )
    tidy_results = pd.melt(
        results,
        id_vars=["city_town", "ward", "precinct"],
        var_name="name",
        value_name="votes",
    )
    return tidy_results

if __name__ == "__main__":
    main()
