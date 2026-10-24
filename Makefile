# Common tasks. Run from the repo root.
.PHONY: build fetch drop simulate reset test serve

build:      ## races.csv + sources.csv -> site/data/races.json
	Rscript R/build_races.R

fetch:      ## one pass of live results -> site/data/results.json
	Rscript R/fetch_results.R

drop:       ## which blocked-host races have a file in the drop folder
	Rscript R/drop_status.R

simulate:   ## fake results for layout testing (flagged simulated)
	Rscript R/simulate_results.R $(STAGE)

reset:      ## clear history and rebuild results.json from real feeds/manual entries
	Rscript R/reset_results.R

test:
	Rscript -e 'testthat::test_dir("R/tests/testthat")'

serve:      ## preview the dashboard at http://localhost:8787
	cd site && python3 -m http.server 8787
