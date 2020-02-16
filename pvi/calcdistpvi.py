import pandas as pd
import electionstats
import pvi

def main():
    pcts = read_merge_precincts()
    print("Output...")
    pcts.to_csv("ma_precincts_districts_12_16_pres.csv", index=False)
    pct_pvi_16 = (pcts[["City/Town", "Ward", "Pct",
                        "cur_dem_votes", "cur_gop_votes", "prev_dem_votes", "prev_gop_votes"]]
                  .assign(pvi_year=2016)
                  .reset_index())
    pct_pvi_16["PVI_N"] = pvi.calc_pvi(pct_pvi_16)
    pct_pvi_16["PVI"] = pct_pvi_16["PVI_N"].map(pvi.pvi_string)
    pct_pvi_16[["City/Town", "Ward", "Pct", "PVI_N", "PVI"]].to_csv("ma_precinct_pvi_2016.csv", index=False)
    ct_pvi_16 = grouping_pvi(pcts, "City/Town")
    ct_pvi_16.to_csv("ma_city_town_pvi_2016.csv", index=False)
    county_pvi_16 = grouping_pvi(pcts, "County")
    county_pvi_16.to_csv("ma_county_pvi_2016.csv", index=False)
    sr_pvi_16 = grouping_pvi(pcts, "State Rep")
    sr_pvi_16.to_csv("ma_state_rep_dist_pvi_2016.csv", index=False)
    ss_pvi_16 = grouping_pvi(pcts, "State Senate")
    ss_pvi_16.to_csv("ma_state_senate_dist_pvi_2016.csv", index=False)
    ush_pvi_16 = grouping_pvi(pcts, "US House")
    ush_pvi_16.to_csv("ma_us_house_dist_pvi_2016.csv", index=False)
    gc_pvi_16 = grouping_pvi(pcts, "Gov Council")
    gc_pvi_16.to_csv("ma_gov_council_dist_pvi_2016.csv", index=False)
    print("Done.")

def read_merge_precincts():    
    print("President 2016...")
    p16 = (office_precincts("President", 2016)
           .rename(columns={"Clinton/ Kaine": "cur_dem_votes",
                            "Trump/ Pence": "cur_gop_votes"})
           [["City/Town", "Ward", "Pct", "cur_dem_votes", "cur_gop_votes"]])
    print("President 2012...")
    p12 = (office_precincts("President", 2012)
           .rename(columns={"Obama/ Biden": "prev_dem_votes",
                            "Romney/ Ryan": "prev_gop_votes"})
           [["City/Town", "Ward", "Pct", "prev_dem_votes", "prev_gop_votes"]])
    print("Counties...")
    ctd = pd.read_csv("ma_town_demographics_2010.csv")
    ctd["City/Town"] = ctd["City/Town"].map(abbreviate_compass)
    print("State Rep 2016...")
    sr16 = (office_precincts("State Rep", 2016)
            [["City/Town", "Ward", "Pct", "district"]]
            .rename(columns={"district": "State Rep"}))
    print("State Senate 2016...")
    ss16 = (office_precincts("State Senate", 2016)
            [["City/Town", "Ward", "Pct", "district"]]
            .rename(columns={"district": "State Senate"}))
    print("US House 2016...")
    ush16 = (office_precincts("US House", 2016)
             [["City/Town", "Ward", "Pct", "district"]]
             .rename(columns={"district": "US House"}))
    print("Gov Council 2016...")
    gc16 = (office_precincts("Gov Council", 2016)
            [["City/Town", "Ward", "Pct", "district"]]
            .rename(columns={"district": "Gov Council"}))
    gc16["Gov Council"] = gc16["Gov Council"].str.lstrip()
    print("Merge...")
    pcts = (pd.merge(sr16,
                     pd.merge(ss16,
                              pd.merge(ush16,
                                       pd.merge(gc16,
                                                pd.merge(p16,
                                                         pd.merge(p12, ctd[["City/Town", "County"]],
                                                                  on="City/Town"),
                                                         on=["City/Town", "Ward", "Pct"]),
                                                on=["City/Town", "Ward", "Pct"]),
                                       on=["City/Town", "Ward", "Pct"]),
                              on=["City/Town", "Ward", "Pct"]),
                     on=["City/Town", "Ward", "Pct"])).sort_values(["City/Town", "Ward", "Pct"])
    return pcts
    
def office_precincts(office, year):
    elecs = electionstats.query_elections(year, year, office, "General")
    elecs["precincts"] = elecs["election_id"].map(electionstats.read_election)
    pcts = pd.concat(list(elecs.apply(add_district, axis=1)), ignore_index=True)
    return pcts
    
def add_district(r):
    p = r["precincts"]
    p["election_id"] = r["election_id"]
    p["office"] = r["office"]
    p["district"] = r["district"]
    return p

def grouping_pvi(pcts, office):
    dists = (pcts[[office, "cur_dem_votes", "cur_gop_votes", "prev_dem_votes", "prev_gop_votes"]]
             .groupby(office)
             .sum()
             .assign(pvi_year=2016)
             .reset_index())
    dists["PVI_N"] = pvi.calc_pvi(dists)
    dists["PVI"] = dists["PVI_N"].map(pvi.pvi_string)
    dpvi = dists[[office, "PVI_N", "PVI"]]
    return dpvi

def abbreviate_compass(name):
    abbr_name = (name.replace("North ", "N. ")
                 .replace("East ", "E. ")
                 .replace("South ", "S. ")
                 .replace("West ", "W. "))
    return abbr_name

if __name__ == "__main__":
    main()
