# Handoff: local Claude Code session on Alex's Mac

Written Oct 16, 2026 by the cloud session that built the tracker. Read `CLAUDE.md` first, then `docs/automation-plan.md`. This file is the ordered to-do list with enough detail to start each item without re-deriving it.

## Why the work moves to the Mac

- The 16 Ohio races hosted on `boe.ohio.gov`, `lookup.boe.ohio.gov`, `liveresults.boe.ohio.gov` and `huron.boe.ohio.gov` answer every plain HTTP client with a JavaScript bot challenge (HTTP 403). Confirmed from GitHub Actions, from the Claude cloud environment, and with curl on the Mac itself (both test URLs returned 403 on Oct 16). A real browser on the Mac passes, which is how the sample ballots and voter files were downloaded.
- Large inputs (the 15 county voter files, county PDFs) live on the Mac and cannot be uploaded to a cloud session.
- The election-night loop has to run on a residential network for the same reason, so the Mac is the primary runner and GitHub Actions is the backup for the 18 reachable sources.

## One-time setup

1. R packages: `install.packages(c("tidyverse", "httr2", "jsonlite", "rvest", "xml2", "readxl", "glue", "cli", "pdftools", "googlesheets4", "testthat", "chromote"))`. Google Chrome or Chromium must be installed; set `CHROMOTE_CHROME` if chromote cannot find it.
2. `make test` passes, `make build` runs, `Rscript R/fetch_results.R --dry-run` runs (feeds will report "no match" or "not found" until election night; that is expected).
3. `gh auth status` works (for workflow runs and pull requests).
4. `googlesheets4::gs4_auth()` once, interactively, if the sheet write-back will run from the Mac. For Actions, a service account per `RUNBOOK.md`.
5. The voter files are in `~/Downloads/county_files/` (15 files named by county).

## Tasks, in order

### T1. Finish the Upper Sandusky registered-voter count (10 minutes)

```
Rscript R/count_registered_voters.R ~/Downloads/county_files --only WYANDOT
```

The script now tries several precinct spellings and, if nothing matches, prints every precinct name and place-column value in `WYANDOT.txt`. Add the right `precinct_rx` for `oh-upper-sandusky` in `OHIO_JURISDICTIONS` if needed, rerun, commit `data/registered_voters_ohio.csv`, and put the number in column G row 23 of the sheet's `manual_results` tab with a source note in column Y.

### T2. Browser-backed fetch for the bot-checked hosts (the unlock for 16 races)

**Status Oct 23: blocked by design.** A spike with chromote (fresh profile, `--headless=new`, then headed) got Cloudflare's "Our security service has detected suspicious activity, and access to the website has been blocked" page on `boe.ohio.gov` within 20 seconds, both ways. The block page is 1.25 MB (inlined fonts), so a size check cannot tell it from a real page; detect it by its title. Getting past it would take stealth patches that hide the automation, which is evading the state's bot detection and is not something to build. Options being decided with Alex: a drop folder that a person's browser downloads into, the sheet's manual override, or asking the SOS/county boards for an allowlist or feed. The design below is kept for reference.

Goal: adapters keep calling `fetch_text()` and `fetch_file()` from `R/utils.R`; for the challenge hosts those helpers go through Chrome instead of httr2.

Design:
- New file `R/browser_fetch.R`. `BROWSER_HOSTS <- c("boe.ohio.gov", "lookup.boe.ohio.gov", "liveresults.boe.ohio.gov", "huron.boe.ohio.gov", "ohiosos.gov")`, matched as host suffixes; `needs_browser(url)` returns TRUE for them. Add `liveresults.franklincountyohio.gov` if a plain fetch from the Mac also gets a 403.
- One Chrome per R process, started lazily: `chromote::Chrome$new(args = c("--user-data-dir=<~/.cache/dcbt-chrome>", "--remote-allow-origins=*", "--headless=new", "--window-size=1280,900"))` and a `ChromoteSession$new(parent = ...)`. The persistent profile keeps the challenge's clearance cookie between runs, so the challenge is solved once per cookie lifetime, not on every poll.
- `browser_fetch_text(url)`: `Page$navigate(url)`, wait for `Page$loadEventFired()`, then poll `Runtime$evaluate("document.documentElement.outerHTML")$result$value` every second for up to 20 seconds until the body no longer contains the challenge markers (`Website Maintenance`, `bot`, `challenge`) and is longer than a few KB. Return the HTML.
- `browser_fetch_bytes(url)`: run inside the page `fetch(url, {credentials: "include"}).then(r => r.arrayBuffer()).then(b => btoa(String.fromCharCode(...new Uint8Array(b))))` through `Runtime$evaluate(..., awaitPromise = TRUE, returnByValue = TRUE)`, decode with `jsonlite::base64_dec()`. Navigate to the host's root first so the fetch is same-origin and carries the cookie. Large PDFs may need chunked base64; the county PDFs are under 1 MB.
- If `--headless=new` still shows the challenge after 20 seconds, retry once with a headed Chrome (drop the headless flag). A visible window on the Mac is acceptable on election night.
- Hook: in `R/utils.R`, `fetch_text()` and `fetch_bytes()` check `needs_browser(url) && requireNamespace("chromote", quietly = TRUE)` and route accordingly. Everything else stays httr2.

Acceptance:
- `fetch_text("https://www.boe.ohio.gov/pickaway/election-info/election-results/")` returns the real page (contains "Election Results", not "Website Maintenance").
- `fetch_file("https://www.boe.ohio.gov/champaign/c/elecres/20260505results.pdf", ".pdf")` yields a PDF that `pdftools::pdf_text()` reads.
- `Rscript R/fetch_results.R --dry-run` shows no bot-check failures for the Ohio sources.
- The Ohio voter-file portal (`www6.ohiosos.gov`) also opens through the same path, which makes future voter-file pulls scriptable.

### T3. Automatic URL discovery (removes every "paste the election id" step)

Add columns `discover_url`, `discover_pattern` (a regex with one capture group) and `discover_pick` (`first`, `last` or `max`) to `data/sources.csv`. Add a `discover_placeholders(sources)` step at the top of `R/fetch_results.R` that fetches each distinct `discover_url` once, applies the pattern, substitutes the capture into `ELECTION_ID` or `PDF_URL` placeholders in `results_url` and `api_url`, and caches `{race_id, placeholder, value, found_at}` in `data/discovered.json` so a transient failure keeps the last good value. Log every discovery. Write tests with saved fixture pages.

Rules found so far (verify each against the live page before relying on it):

| Source | discover_url | pattern | notes |
|---|---|---|---|
| Madison IL (4 townships), Bloomington | `https://results.enr.clarityelections.com/IL/<County>/elections.json?v=1` | JSON, pick the row whose `Date` starts `11/3/2026`, use `EID` | verified Oct 16 for both; Madison's response is gzip-compressed (httr2 handles it; curl needs `--compressed`). Then switch these five races to `adapter = clarity` with `api_url = https://results.enr.clarityelections.com/IL/<County>/ELECTION_ID`. Set `contest_pattern` from the contest names in the March 2026 primary file (Bloomington id 126005). |
| Will County | unknown | | `IL/Will/elections.json` is empty and `will-il.connect.clarityelections.com` returns 404. Find where the clerk publishes live results (the clerk page links only PDFs today); call the clerk's office if needed. |
| LA County | `https://results.lavote.gov/electionresults/json?electionid=<id>` | the election-list page is Incapsula-protected; probe ids upward from 4338 until one returns the Nov 3, 2026 election, or read the id in a browser | JSON endpoint verified reachable from Actions |
| Volusia | `https://enr.electionsfl.org/VOL/` or the Volusia SOE results page | newest `/VOL/(\d+)/` | the old `vrcdn.electionsfl.org/StaticPages/volusia.html` landing now redirects to a state directory |
| Morgan County IL | `https://morgancounty-il.com/wp/departments/county-clerk/` | `county_results\.asp\?id=(\d+)` | GBS home page has no election list |
| Franklin OH ENR | `https://liveresults.franklincountyohio.gov/enr/franklinohenr/` | `index_(\d+)\.html`, pick max | may need the browser path |
| Butler OH, Lucas OH ENR | `https://liveresults.boe.ohio.gov/ENR/butlerohenr/` and `.../lucasohenr/` | same pattern | browser path |
| boe.ohio.gov PDF counties | the county's election-results page | newest `href` ending `.pdf` whose name matches `cumulative|summary|results` | browser path |
| Delaware OH | `https://vote.delawarecountyohio.gov/` | newest `/wp-content/uploads/2026/11/[^"]+\.pdf` | |
| Trumbull OH | `https://boe.co.trumbull.oh.gov/boe_results.html` | newest `pdfs/[^"]+\.pdf` under the 2026 heading | |
| Lake OH | none | fixed `https://webapps.lakecountyohio.gov/boe/web1.pdf` | verified reachable |
| Lyon KS, Butler KS, Franklin KS | the clerk's election-results page | newest `/DocumentCenter/View/\d+[^"]*` whose name contains `Result` and `2026` (Franklin KS names them like `Official-Election-Results-2026-Primary_COMPLETE`) | Lyon's page lists per-election subpages (`/391/2026-Primary-Election-Results`); two-step discovery |
| Huron OH | `https://www.huron.boe.ohio.gov/` | the Nov 3, 2026 unofficial-results link already present as a placeholder | browser path |
| Clark NV, Rock WI | none | fixed URLs | verified |

### T4. Dress rehearsal against the May 2026 primary

Run every adapter against that election's artifacts, save the fetched files under `R/tests/testthat/fixtures/`, and make tests that parse them. Known artifacts: Butler OH ENR `/23/`, LA County 4338, Bloomington 126005, Rock County `20260407.html`, Lake County `web1.pdf`, Delaware's `418_PALL_Election_SummaryWriteIn.pdf`, Trumbull's `Election Summary050526.pdf`, Clark County's primary ENR, Madison IL's primary on Clarity, Ashtabula and Champaign `20260505results.pdf` (browser path). This is where the PDF adapter (currently "first 15 lines after the contest heading") gets a layout per vendor: Triad for the boe.ohio.gov counties, Hart for Delaware, ES&S for Kansas. Each county's May PDF shows the real layout.

### T5. Harden the Mac loop and make Actions the polite backup

- `R/watch.R`: `git pull --rebase` before push, a lock file so two loops cannot run, exponential backoff after failures, a log file under `logs/`, and a `launchd` plist (`~/Library/LaunchAgents/`) that runs it with `caffeinate` so the laptop does not sleep. Document in `RUNBOOK.md`.
- `update-results.yml`: skip the run when the last commit touching `site/data/results.json` is less than 10 minutes old (the Mac is alive); cache R packages (or a `rocker/r-ver` image) so a run takes about 30 seconds; widen the cron to Nov 3 through 6.

### T6. Plausibility checks, status file, alerts

In `derive_fields`: YES plus NO must not exceed registered voters (column G of the sheet and `data/registered_voters_ohio.csv`; put them into `data/races.csv` as a `registered_voters` column), precincts reporting must not decrease, totals must not fall by more than a small margin. A failed check keeps the previous numbers and sets `note = "needs review"`. Write `site/data/status.json` (adapter, last success, last error, check result per race) and render a feed-health strip on the dashboard. Alert through a Slack webhook or email when a feed fails twice in a row or a race has no numbers 90 minutes after its polls close.

### T7. Sheet write-back without the hourly lag

Either the service account route in `RUNBOOK.md` (secrets in Actions) or, since the loop runs on the Mac, call `push_results_to_sheet()` with an interactive `gs4_auth()` token cached on the Mac. Then the `live_results` tab no longer depends on `IMPORTDATA`.

### T8. Remaining ballot documents and registered-voter gaps

Sample ballots still open: Volusia (Edgewater), Butler KS (El Dorado), Franklin KS (Ottawa), Morgan IL. Registered voters still missing: Upper Sandusky (T1), Morgan County IL, Joliet Township, the four Madison County townships, the three Kansas cities. Clarity's per-precinct `totalVoters` may give the Illinois townships once the Nov 3 election is published.

### T9. Election-night supervision

On the night, run the loop under `launchd` and keep a Claude Code session open in the repo with `/loop` watching `logs/` and `site/data/status.json`, fixing parser misses as they happen (a new PDF layout, a renamed contest) and writing the sheet override when a feed is hopeless. Poll closing times, Eastern: 7:00 Florida, 7:30 Ohio, 8:00 Kansas and Illinois, 9:00 Wisconsin, 10:00 Nevada, 11:00 California.

## Do not redo

- The registry research is done; Ballotpedia's 21 Ohio measures in 18 jurisdictions reconcile with the registry once Piqua is set aside. Do not re-research the list.
- Documents already in `docs/source-docs/` are applied; their statuses are in `docs/research/documents-to-fetch.md`.
- The sheet's structure, formulas and instructions are final unless a column is added at the end.
- Do not try headers, user agents or retries against the Ohio hosts; only a browser passes.

## Open questions for Alex

- Where will Will County publish Nov 3 results (Clarity id, or something else)?
- Should the dashboard show turnout against registration now that registered voters are known for 28 races? (Cheap once T6 puts the column in the registry.)
- Slack webhook or email for alerts?
