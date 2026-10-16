# Data Centers on the Ballot: guide for Claude sessions

Election-night tracker for every US data center ballot measure on Nov 3, 2026. Owner: Alex Lundry, Redbud Consulting (writes R, tidyverse). Public dashboard: https://alexlundry.github.io/data_center_ballot_tracker/. Repo: https://github.com/alexlundry/data_center_ballot_tracker.

Read `docs/automation-plan.md` (what is and is not automated, and why) and `docs/handoff-local-session.md` (the current task list) before starting pipeline work.

## Layout

- `data/races.csv`: the registry, 44 rows (34 on the Nov 3 ballot, the rest decided earlier or on other dates). One row per question; Wilmington OH has four.
- `data/sources.csv`: results feeds per race, tried by `priority`; `adapter` names a parser in `R/adapters/`.
- `data/manual_results.csv`, `data/not_on_ballot.csv`, `data/registered_voters_ohio.csv`, `data/history.csv` (election-night change log, written by the pipeline).
- `R/`: `build_races.R` (registry to `site/data/races.json`), `fetch_results.R` (one pass of every feed to `site/data/results.json` and `results.csv`), `adapters/`, `utils.R` (HTTP and parsing helpers), `write_sheet.R`, `watch.R` (laptop loop), `count_registered_voters.R`, `simulate_results.R`, `reset_results.R`, `tests/testthat/`.
- `site/index.html`: the whole dashboard, one file, inline CSS and JS, d3 and topojson-client from CDNs. `site/data/` holds the JSON it reads.
- `docs/`: `automation-plan.md`, `handoff-local-session.md`, `research/documents-to-fetch.md` (which official documents have been fetched), `source-docs/` (the official ballot documents themselves).
- `.github/workflows/`: `update-results.yml` (cron every 5 min on Nov 3 and 4), `deploy-pages.yml` (on push to `site/**`), `test.yml`, `probe-sources.yml` (manual reachability check).
- `README.md` explains the system; `RUNBOOK.md` is the election-night procedure.

## Commands

```
make build        # races.csv + sources.csv -> site/data/races.json (run after editing either)
make fetch        # one pass of live results
make test         # testthat suite
make serve        # dashboard at http://localhost:8787
Rscript R/fetch_results.R --dry-run
Rscript R/watch.R 120                         # election-night loop
Rscript R/count_registered_voters.R <folder> [--only WYANDOT]
```

## Rules that must hold

- `race_id` is the key everywhere (registry, sources, results, history, the Google Sheet). Never rename one.
- `yes_means` (`restrict` or `allow`) says what a YES vote does to data centers. Enter YES and NO exactly as the county labels them; `derive_fields` in `R/utils.R` turns them into restrict and allow. Never flip at entry. Sprigg and Monroe townships print "For / Against the Zoning Resolution" (For is yes); everything else is Yes / No.
- `ballot_text_verbatim` is TRUE only when the text is exactly what the official ballot or document prints. Otherwise FALSE, with the reconstructed parts flagged inside the text. Cite the document in `notes` by its `docs/source-docs/` path, and mark the item fetched in `docs/research/documents-to-fetch.md`.
- Registry decisions Alex has already made: East Whiteland Township PA stays out; the Georgia May 19 party-primary advisory questions stay in (different date); Piqua OH moved to Feb 2, 2027 and sits in `not_on_ballot.csv`; the Clarksville AR Dec 1 bond referendums are a watch-list item, not registry rows. Monroeville OH is advisory (per its ballot), Upper Sandusky's origin is `charter_commission`, Monterey Park was council-placed.
- Decided measures keep their rows with `status = decided` so the dashboard's decided section can show them.
- `site/data/results.json` is committed only when the counts change (the workflow's jq guard strips `generated_at`). Do not create commits for timestamp churn.
- Dashboard: one light theme with Redbud tokens (cream `#faf5f1`, paper `#fff`, ink `#2a1a26`, magenta `#a8336e`; restrict `#3273a3`, allow `#b35a26`). Tooltips use `data-tip` attributes; stars live in `localStorage` key `dcbt_starred`. Keep it one file, no frameworks. Check it in a browser (or headless Chromium) before pushing.
- Google Sheet `1jma2RqwyFNB8dP23f0nM4LCRti54uBJBoqEIktR9fRs`: tabs `manual_results` (gid 0; columns A to Y, including `expected_update` W, `update_note` X, `registered_voters_source` Y), `live_results` (IMPORTDATA of `results.csv`, refresh key in `instructions!B25`), `races`, `instructions`. Never rename tabs or columns or sort `manual_results`; the pipeline reads the gid 0 CSV export and matches on `race_id`.
- Always `git pull --rebase` before pushing; the Actions bot commits results on election night.
- Never put credentials in the repo. Sheet write-back uses `GOOGLE_SA_JSON` and `RESULTS_SHEET_ID` from the environment.

## Network facts (verified Oct 16, 2026)

- `boe.ohio.gov`, `lookup.boe.ohio.gov`, `liveresults.boe.ohio.gov`, `huron.boe.ohio.gov` and `ohiosos.gov` (including the `www6` voter-file portal) answer plain HTTP clients with a JavaScript bot challenge (HTTP 403) from every origin tested: GitHub Actions, the Claude cloud environment, and curl on Alex's Mac. A real browser passes. Those hosts need the browser-backed fetch described in the handoff; do not spend time on headers, user agents or retries.
- `liveresults.franklincountyohio.gov` returned 403 from the cloud and is untested from the Mac.
- `results.lavote.gov`'s election-list page is Incapsula-protected, but its JSON results endpoint works.
- Every other host in `sources.csv` is reachable from GitHub Actions (`probe-sources.yml` run of Oct 16).
- The Ohio Secretary of State's live results do not carry local issues; county sites are the only source for the 20 Ohio measures.

## Where things stand

- Ballot wording is verbatim for 29 of 34 Nov 3 measures. Still open: Volusia (Edgewater), Butler KS (El Dorado), Franklin KS (Ottawa) and Morgan IL sample ballots.
- Registered voters are on the sheet (column G) for 28 of 34 races, from official files; Upper Sandusky needs the `--only WYANDOT` rerun; the non-Ohio gaps are explained in column Y.
- Feeds: as of Oct 16 no source will produce numbers on election night without either a browser-backed fetch (Ohio) or an election id that counties have not published yet. The plan to fix that is `docs/automation-plan.md`; the ordered task list is `docs/handoff-local-session.md`.
