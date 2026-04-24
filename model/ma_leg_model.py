import pandas as pd
import bambi as bmb
from catboost import CatBoostRegressor
from sklearn.metrics import root_mean_squared_error

CAT_FEATURES = [
    "office",
    "district",
    "city_town_incumbent",
    "party_incumbent",
    "city_town_dem",
    "city_town_gop",
    "city_town_third_party",
    "party_third_party",
    "city_town_write_in",
    "party_write_in",
    "incumbent_status",
]

DATE_FEATURES = ["election_date"]

X_FEATURES = (
    CAT_FEATURES
    + DATE_FEATURES
    + [
        "is_special",
        "num_candidates",
        "election_year",
        "pres_elec",
        "PVI_N",
    ]
)

Y_FEATURE = "dem_margin"

SPLIT_DATES = [
    "2016-11-08",
    "2018-11-06",
    "2020-11-03",
    "2022-11-08",
]


def main():
    disable_progress_messages()
    ma_leg = pd.read_csv(
        "ma_leg_two_party_2008_2024.csv", parse_dates=DATE_FEATURES
    ).fillna({key: "None" for key in CAT_FEATURES})
    # test_and_print(ma_leg, bayesian_train_test)
    test_and_print(ma_leg, catboost_train_test)

    
def test_and_print(df, train_test_fn):    
    result_df = test_split_dates(df, SPLIT_DATES, train_test_fn)
    rmse_by_split = (
        result_df.groupby("split_date")[["dem_margin", "pred_dem_margin"]]
        .apply(
            (
                lambda group: root_mean_squared_error(
                    group["dem_margin"], group["pred_dem_margin"]
                )
            )
        )
        .reset_index(name="rmse")
    )
    print(rmse_by_split)
    total_rmse = root_mean_squared_error(
        result_df["dem_margin"],
        result_df["pred_dem_margin"],
    )
    print(f"Total RMSE: {total_rmse}")


def test_split_dates(df, split_dates, train_test_fn):
    results = []
    for split_date in SPLIT_DATES:
        test_results = train_test_fn(df, split_date)
        results.append(test_results)
    result_df = pd.concat(results, ignore_index=True)
    return result_df


def bayesian_train_test(df, split_date):
    print(split_date)
    train_df, test_df = train_test_split(df, split_date)
    model = bmb.Model(
        "dem_margin ~ PVI_N + incumbent_status + pres_elec", data=train_df
    )
    idata = model.fit(progressbar=False)
    test_idata = model.predict(
        idata,
        data=test_df,
        kind="response",
        inplace=False
    )
    results = test_df.copy().assign(
        pred_dem_margin = (
            (test_idata["posterior_predictive"]["dem_margin"]
             .mean(dim=["chain", "draw"]).values)
        ),
        split_date = split_date,
    )
    return results

def catboost_train_test(df, split_date):
    print(split_date)
    train_df, test_df = train_test_split(df, split_date)
    model = CatBoostRegressor(silent=True, has_time=True)
    model.fit(train_df[X_FEATURES], train_df[Y_FEATURE], cat_features=CAT_FEATURES)
    pred_dem_margin = model.predict(test_df[X_FEATURES])
    results = test_df.copy().assign(
        pred_dem_margin=pred_dem_margin, split_date=split_date
    )
    return results


def train_test_split(df, split_date):
    train_df = df[df["election_date"] < split_date]
    test_df = df[df["election_date"] >= split_date]
    return train_df, test_df


def feature_importances(model):
    fi = pd.DataFrame(
        {
            "feature": X_FEATURES,
            "importance": model.feature_importances_,
        }
    ).sort_values("importance", ascending=False)
    return fi

def disable_progress_messages():
    import logging
    logger = logging.getLogger("pymc")
    logger.setLevel(logging.ERROR)

def worcester_and_middlesex():
    ma_leg = pd.read_csv(
        "ma_leg_two_party_2008_2024.csv", parse_dates=DATE_FEATURES
    ).fillna({key: "None" for key in CAT_FEATURES})
    model = CatBoostRegressor(silent=True, has_time=True)
    worc_mid_2024 = (
        ma_leg
        .query("district == 'Worcester and Middlesex'")
        .query("pvi_year == 2022")
        .assign(pres_elec=True)
    )
    model.fit(
        ma_leg[X_FEATURES],
        ma_leg[Y_FEATURE],
        cat_features=CAT_FEATURES,
    )
    model.predict(worc_mid_2024[X_FEATURES])
    

if __name__ == "__main__":
    main()
