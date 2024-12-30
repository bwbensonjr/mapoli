import pandas as pd

def main():
    elecs = pd.read_csv(
        "https://bwbensonjr.github.io/ma-election-db/"
        "data/ma_general_election_summaries_1990_2024.csv.gz"
    )
    
    senate_ids = (elecs
                  .query("election_date == '2024-11-05'")
                  .query("office == 'State Senate'")
                  ["election_id"])
    rep_ids = (elecs
               .query("election_date == '2024-11-05'")
               .query("office == 'State Representative'")
                  ["election_id"])
