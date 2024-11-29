import pandas as pd
import sys

RESULTS_URL = "http://electionstats.state.ma.us/elections/download/{election_id}/precincts_include:1"

def main():
    election_id = sys.argv[1]
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
    results.to_csv(sys.stdout, index=False)

if __name__ == "__main__":
    main()
