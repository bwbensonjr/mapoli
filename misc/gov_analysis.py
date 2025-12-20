import polars as pl
from pyprojroot import find_root, has_file


def main():
    root = find_root(has_file(".here"))
    df = (
        pl.read_csv(root / "results" / "MA-Governor-2022-11-08.csv")
        .drop("office", "district")
        .with_columns(
            [
                # Calculate total votes per precinct (excluding "Total Votes Cast" row to avoid double-counting)
                pl.when(pl.col("receiver") != "Total Votes Cast")
                .then(pl.col("votes"))
                .otherwise(0)
                .sum()
                .over(["city_town", "ward", "precinct"])
                .alias("precinct_total_votes"),
                # Calculate max votes per precinct among actual candidates only
                pl.when(
                    ~pl.col("receiver").is_in(
                        ["Total Votes Cast", "Blanks", "All Others"]
                    )
                )
                .then(pl.col("votes"))
                .otherwise(None)
                .max()
                .over(["city_town", "ward", "precinct"])
                .alias("max_candidate_votes"),
            ]
        )
        .with_columns(
            [
                # Calculate percentage of votes
                (pl.col("votes") / pl.col("precinct_total_votes") * 100).alias(
                    "precinct_pct"
                ),
                # Mark if this candidate won the precinct (only actual candidates)
                (
                    (pl.col("votes") == pl.col("max_candidate_votes"))
                    & (
                        ~pl.col("receiver").is_in(
                            ["Total Votes Cast", "Blanks", "All Others"]
                        )
                    )
                ).alias("precinct_winner"),
            ]
        )
        # Clean up temporary column
        .drop("max_candidate_votes")
    )
    df.filter(pl.col("precinct_winner")).group_by("receiver").len().sort(
        "len", descending=True
    )


if __name__ == "__main__":
    main()
