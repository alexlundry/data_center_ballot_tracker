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
2. **`data/sources.csv`** says where each race's live numbers come from: an adapter name (`clarity`, `json_generic`, `csv_generic`, `html_table`, `ohio_sos`, `pdf`, `sheet`, `manual`), the page URL people click through to, the machine endpoint, a regex that identifies the contest, and optional yes/no label regexes. Several rows per race are fine; they are tried in `priority` order.
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
| Ohio | 20 in 17 jurisdictions | 9 use the Conserve Ohio 25 MW charter template; Hubbard is a full ban; Perry Village (Issue 16) requires a 31-year bond from hyperscale developers seeking tax breaks; Wilmington has 4 rezoning referendums (YES = allow); Ashville is a referendum on an EdgeConneX agreement (YES = allow); Monroeville is a proposed ordinance allowing data center development (YES = allow) |
| Illinois | 7, all advisory | Bloomington and Morgan County (YES = restrict); Joliet Township and four Madison County townships (YES = allow) |
| Kansas | 3 | Emporia, El Dorado, Ottawa (initiated ordinances; Emporia and Ottawa have court questions pending) |
| Wisconsin | 1 | Janesville GM/JATCO $450M voter-approval question |
| California | 1 | Alhambra Measure DB |
| Nevada | 1 | Boulder City Question 1 (YES = allow) |
| Florida | 1 | Edgewater Charter Amendment 4 |

Decided earlier in 2026: Port Washington WI (Apr 7, passed), Georgia party-primary advisory questions (May 19), Monterey Park CA (June 2, passed 88%), Augusta Township MI (Aug 4, rezoning repealed 90% to 10%), Wrightstown WI (Aug 11, advisory rejected 87% to 13%). Not on the ballot: Piqua OH (Feb 2027), Frederick County MD (blocked in court), Weld County CO (pending), statewide Ohio (2027) and Massachusetts (2028). See `docs/research/`.

Ballotpedia's count of 21 Ohio measures in 18 jurisdictions reconciles exactly with this registry once Piqua (moved to Feb 2027) is set aside; the registry has 34 November measures nationally. East Whiteland Township, PA's board-expansion question (born of a data center fight but not about data centers on its face) is deliberately excluded. The likely gap is one more Ohio jurisdiction (and Piqua, which moved to February). Issue numbers are confirmed only for Conneaut (10), Perry (16), Trenton (17), Oregon (25) and Grove City (28); the Ohio SOS "Local Questions and Issues" spreadsheet for Nov 3 resolves the rest. Ballot wording is verbatim for 29 of the 34 November measures (full amendment text for Urbana, Sunbury, Oregon, Conneaut, Defiance, Ashville and the four Wilmington referendums and the Sprigg and Monroe township zoning questions from county sample ballots and proofs, the Upper Sandusky and Janesville question lines, the Emporia ballot form from Resolution 3799, and Edgewater's official title and summary, all in `docs/source-docs/`) and partial or summarized for the rest, flagged on each card. Full texts of the Grove City Issue 28 amendment and the Perry Village ordinance are also in `docs/source-docs/`. The Ohio Secretary of State's Nov 3 Local Questions and Issues file (Sept 18 version, in `docs/source-docs/`) confirms every Ohio entry except Conneaut, which the Ashtabula County BOE certified separately; it carries no issue numbers.

## What the results sources look like (verified Oct 15, 2026)

| Feed type | Counties | Adapter | Status |
|---|---|---|---|
| Scytl/Clarity JSON + CSV | Will County IL (probable) | `clarity` | election ID needed on the night |
| LA County JSON feed | Los Angeles County (Alhambra) | `json_generic` | endpoint pattern verified; Nov 3 election ID not yet listed |
| Ohio ENR platform (HTML index with CSV/XML exports) | Butler, Franklin, Lucas | `html_table`, `csv_generic` | instance ID increments per election |
| VR Systems ENR (HTML + CSV report) | Volusia FL | `html_table`, `csv_generic` | election ID needed |
| GBS results portal (HTML) | Morgan County IL | `html_table` | election ID needed |
| Static HTML by date | Rock County WI | `html_table` | pattern verified |
| County ENR / SOS HTML | Clark NV | `html_table` | verified |
| PDF summary reports | the other 12 Ohio counties, all 3 Kansas counties, Bloomington Election Commission, Madison County IL | `pdf` | best effort; manual entry is the backstop |

Ohio's Secretary of State live site reports statewide contests and State Issue 3 only (Directives 2026-22 and 2026-48), so every Ohio measure is read from its county board.

## Adding or fixing a race

1. Add or edit the row in `data/races.csv` (keep `race_id` stable).
2. Add one or more rows in `data/sources.csv`. Until you know the night-of URL, leave the adapter in place with `source_status = unverified`; the dashboard shows the human results page link regardless.
3. `make build`, then `make fetch --dry-run` style check: `Rscript R/fetch_results.R --dry-run`.

## Manual entry on election night

Put numbers in the Google Sheet "Data Center Ballot Tracker — Election Night Manual Entry" (its `manual_results` tab is pre-filled with one row per November measure and is read by the `sheet` row in `sources.csv`; it must be shared as Anyone with the link > Viewer or published to the web) or in `data/manual_results.csv`: `race_id, yes_votes, no_votes, precincts_reporting, precincts_total, status (final when complete), as_of, source_url, override (TRUE to beat the automated feed), entered_by, note`. The next pipeline pass picks it up.

## Registered voters from the Ohio voter file

The Ohio Secretary of State's voter file portal (https://www6.ohiosos.gov/ords/f?p=VOTERFTP:HOME) answers automated requests with a bot check, so the county files have to be downloaded by hand. Download the county files for Adams (1), Ashtabula (4), Butler (9), Champaign (11), Clinton (14), Defiance (20), Delaware (21), Franklin (25), Huron (39), Lake (43), Licking (45), Lucas (48), Pickaway (65), Trumbull (78) and Wyandot (88) into one folder, then run:

```
Rscript R/count_registered_voters.R ~/Downloads/ohio-voter-files
```

It writes `data/registered_voters_ohio.csv` with one row per Ohio race (total and active registrations, the matching rule used, and the source file), and prints county totals for reference. Cities and villages are matched on the CITY / VILLAGE columns; the Sprigg and Monroe township zoning questions count the unincorporated area only (TOWNSHIP set, CITY and VILLAGE blank). Add `--write-sheet` to push the counts into columns G and Y of the manual_results tab of the election-night sheet (googlesheets4, interactive login; `--sheet <id>` overrides the sheet).

## Design

Redbud research-deliverable design system: cream paper, white cards, plum-black ink, magenta accent, navy hero; Source Serif 4 / IBM Plex Sans / IBM Plex Mono. The two data colors (blue for Restrict, clay for Allow) were validated for color-vision deficiency and contrast on both the white cards and the navy hero.
