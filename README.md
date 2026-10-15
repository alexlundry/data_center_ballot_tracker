# Data Centers on the Ballot · Election Night 2026

An election-night tracker, by [Redbud Consulting](https://www.redbud.consulting), for every data center ballot measure in the United States on November 3, 2026: bans, megawatt caps, zoning referendums on data center sites, developer agreements, voter-approval requirements and advisory questions. It shows aggregate statistics (how many measures, by level and state; how many the anti-data-center side is winning; the average and pooled vote shares), a map, a filterable card and table view of every race with ballot text and click-throughs to the county results page, a poll-closing schedule and update log, and the questions voters already settled earlier in 2026.

```
site/            the dashboard (static: index.html + data/ + assets/)
data/            the registry you edit: races.csv, sources.csv, manual_results.csv, not_on_ballot.csv
R/               the tidyverse pipeline that turns the registry + live feeds into site/data/*.json
docs/research/   research notes with links for every measure
.github/         Actions: results refresh every 5 minutes, Pages deploy, tests
RUNBOOK.md       what to do on election night
```

## How it fits together

1. **`data/races.csv`** is the master list: one row per measure with jurisdiction, county, level, type, whether a YES vote restricts or allows data centers (`yes_means`), the ballot text, status, coordinates and links. `R/build_races.R` turns it into `site/data/races.json`.
2. **`data/sources.csv`** says where each race's live numbers come from: an adapter name (`clarity`, `json_generic`, `html_table`, `ohio_sos`, `pdf`, `sheet`, `manual`), the page URL people click through to, the machine endpoint, a regex that identifies the contest, and optional yes/no label regexes. Several rows per race are fine; they are tried in `priority` order.
3. **`R/fetch_results.R`** runs every adapter, standardizes everything to yes/no votes + precincts, applies manual overrides, appends to `data/history.csv`, and writes `site/data/results.json`. If a feed fails the previous numbers are kept and flagged stale.
4. **`site/index.html`** reads the two JSON files, refreshes every minute, and does all aggregation in the browser. It also has a **Simulate returns** button that fills the page with made-up numbers (loudly labeled) so you can see how the layout behaves before any real results exist.
5. **`.github/workflows/update-results.yml`** runs step 3 on a 5-minute cron and commits the JSON; **`deploy-pages.yml`** publishes `site/` to GitHub Pages. `netlify.toml` does the same for Netlify. `R/watch.R` is a laptop loop for nights when GitHub's cron lags.

## Running it locally

```sh
# R packages (once)
Rscript -e 'install.packages(c("tidyverse","httr2","jsonlite","rvest","xml2","readxl","glue","cli","pdftools","testthat"))'

make build      # registry -> site/data/races.json
make fetch      # live feeds -> site/data/results.json (safe to run any time)
make simulate   # or: Rscript R/simulate_results.R 0.3   (flagged simulated)
make reset      # clear history + rebuild from real feeds/manual entries
make test       # adapter unit tests
make serve      # http://localhost:8787
```

## The two sides

Every question is mapped to **Restrict** (the anti-data-center outcome) and **Allow** (the pro-data-center outcome). For a ban or a moratorium, YES is Restrict. For "should the council approve data centers", a rezoning referendum, or Boulder City's land-use question, YES is Allow, and the tracker flips the sides so totals add up. `yes_means` in `races.csv` is the single switch; get it right and everything downstream follows.

## What's in the registry (as of Oct 15, 2026)

| | Measures on Nov 3 | Notes |
|---|---|---|
| Ohio | 19 in 16 jurisdictions | 9 use the Conserve Ohio 25 MW charter template; Hubbard is a full ban; Wilmington has 4 rezoning referendums (YES = allow); Ashville is a referendum on an EdgeConneX agreement (YES = allow); Monroeville is advisory (YES = allow) |
| Illinois | 7, all advisory | Bloomington and Morgan County (YES = restrict); Joliet Township and four Madison County townships (YES = allow) |
| Kansas | 3 | Emporia, El Dorado, Ottawa (initiated ordinances; Emporia and Ottawa have court questions pending) |
| Wisconsin | 1 | Janesville GM/JATCO $450M voter-approval question |
| California | 1 | Alhambra Measure DB |
| Nevada | 1 | Boulder City Question 1 (YES = allow) |
| Florida | 1 | Edgewater Charter Amendment 4 |

Decided earlier in 2026: Port Washington WI (Apr 7, passed), Georgia party-primary advisory questions (May 19), Monterey Park CA (June 2, passed 88%), Augusta Township MI (Aug 4, rezoning repealed 90% to 10%), Wrightstown WI (Aug 11, advisory rejected 87% to 13%). Not on the ballot: Piqua OH (Feb 2027), Frederick County MD (blocked in court), Weld County CO (pending), statewide Ohio (2027) and Massachusetts (2028). See `docs/research/`.

Ballotpedia counted 34–35 November measures; this registry has 33. East Whiteland Township, PA's board-expansion question (born of a data center fight but not about data centers on its face) is deliberately excluded. The likely gap is one more Ohio jurisdiction (and Piqua, which moved to February). Issue numbers and verbatim text are still missing for most Ohio measures; the Ohio SOS "Local Questions and Issues" spreadsheet for Nov 3 resolves both.

## Adding or fixing a race

1. Add or edit the row in `data/races.csv` (keep `race_id` stable).
2. Add one or more rows in `data/sources.csv`. Until you know the night-of URL, leave the adapter in place with `source_status = unverified`; the dashboard shows the human results page link regardless.
3. `make build`, then `make fetch --dry-run` style check: `Rscript R/fetch_results.R --dry-run`.

## Manual entry on election night

Put numbers in `data/manual_results.csv` (or the Google Sheet mirrored by the `sheet` row in `sources.csv`): `race_id, yes_votes, no_votes, precincts_reporting, precincts_total, status (final when complete), as_of, source_url, override (TRUE to beat the automated feed), entered_by, note`. The next pipeline pass picks it up.

## Design

Redbud research-deliverable design system: cream paper, white cards, plum-black ink, magenta accent, navy hero; Source Serif 4 / IBM Plex Sans / IBM Plex Mono. The two data colors (blue for Restrict, clay for Allow) were validated for color-vision deficiency and contrast on both the white cards and the navy hero.
