all: pres_2024 pres_2020 pres_2016

pres_2024:
	python ma_results.py 2024-11-05 President

us_house_2024:
	python ma_results.py 2024-11-05 "U.S. House"

gov_2022:
	python ma_results.py 2022-11-08 Governor

pres_2020:
	python ma_results.py 140751 > ma_pres_results_by_precinct_2020.csv

pres_2016:
	python ma_results.py 130243 > ma_pres_results_by_precinct_2016.csv
