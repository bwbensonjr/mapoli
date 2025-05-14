state_rep_summary:
	quarto render office_info.qmd --to html \
             --execute-param office_name:"State Representative" \
             --output state-rep-districts.html --output-dir pages

state_senate_summary:
	quarto render office_info.qmd --to html \
             --execute-param office_name:"State Senate" \
             --output state-senate-districts.html --output-dir pages

gov_council_summary:
	quarto render office_info.qmd --to html \
             --execute-param office_name:"Governor's Council" \
             --output gov-council-districts.html --output-dir pages

us_house_summary:
	quarto render office_info.qmd --to html \
             --execute-param office_name:"U.S. House" \
             --output us-house-districts.html --output-dir pages

office_summaries: state_rep_summary state_senate_summary gov_council_summary us_house_summary


