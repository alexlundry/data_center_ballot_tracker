# Automation plan: getting election night as close to hands-off as possible

Status as of Oct 16, 2026. This reviews every part of the pipeline against one question: on the night of Nov 3, which numbers will appear on the dashboard with nobody typing anything, and what stands in the way for the rest.

## 1. Where things stand, with evidence

**Honest baseline.** Of the 34 November measures, zero have a results source that is guaranteed to produce numbers on election night without a person first pasting in a URL or election id. The "AUTO" label on the sheet means the county has a machine-readable feed we know how to parse, not that the pipeline can reach it unaided today. Three things block full automation, in order of weight.

**Blocker 1: bot checks on the Ohio hosts (16 of 34 races).** A probe run from the GitHub Actions runner on Oct 16 (workflow `Probe results sources`, run 38954703783) got a bot-check page from every `boe.ohio.gov`, `lookup.boe.ohio.gov`, `liveresults.boe.ohio.gov`, `huron.boe.ohio.gov` and `ohiosos.gov` URL. The Claude cloud environment gets the same page. These hosts carry Ashville, Conneaut, Defiance, Granville, Pataskala, Monroe and Sprigg townships, Monroeville, Upper Sandusky, Urbana, the four Wilmington questions, and the Butler (Trenton) and Lucas (Oregon) election-night reporting sites. The Ohio Secretary of State's live results do not carry local issues, so there is no statewide fallback. Nothing in the Claude environment settings or the choice of model changes this; it is the target sites' bot management rejecting datacenter traffic.

**Blocker 2: election-specific URLs that do not exist yet (11 races).** LA County (Alhambra), Volusia (Edgewater), Will County (Joliet Twp), Morgan County (GBS portal), Franklin OH (Grove City), Butler OH (Trenton) and Lucas OH (Oregon) all need a Nov 3 election id that appears only when the county publishes it. The three Kansas counties and Delaware OH post a fresh PDF with an unpredictable link. Today each of these is a hand edit to `data/sources.csv` on election night.

**Blocker 3: cadence and latency.** GitHub's scheduler runs no more often than every five minutes and routinely lags 10 to 30 minutes on busy nights. Each run spends two to three minutes installing R packages. Pages takes about a minute to deploy. Best case, a county update reaches the dashboard 7 to 10 minutes later; worst case, 30 or more. The sheet's `live_results` tab refreshes from `IMPORTDATA` only about hourly because the service-account write-back is not configured.

**What already works.** The adapter design (manual override, then automated sources by priority, then stale fallback), the counts-changed commit guard, the history log, the dashboard's stale and error states, and the manual sheet as a backstop are all sound. The Clarity, VR Systems, LA County JSON, Clark County ENR and Rock County pages are reachable from Actions and parseable.

## 2. Reachability of every source

From the Oct 16 probe. "Actions" is the GitHub runner; "Cloud" is the Claude environment.

| Races | Host | Actions | Cloud | Missing today |
|---|---|---|---|---|
| Ashville, Conneaut, Defiance, Granville, Pataskala, Monroe Twp, Sprigg Twp, Upper Sandusky, Urbana, Wilmington x4 | boe.ohio.gov | blocked | blocked | reachable runner; PDF link |
| Monroeville | huron.boe.ohio.gov | blocked | blocked | reachable runner; PDF link |
| Trenton, Oregon | liveresults.boe.ohio.gov | blocked | blocked | reachable runner; election id |
| Grove City | liveresults.franklincountyohio.gov | untested (403 from cloud) | blocked | election id |
| Hubbard | boe.co.trumbull.oh.gov | ok | ok | PDF link |
| Perry Village | webapps.lakecountyohio.gov | ok | ok | nothing (fixed URL) |
| Sunbury | vote.delawarecountyohio.gov | ok | ok | PDF link |
| Alhambra | results.lavote.gov JSON | ok | ok | election id (list page is Incapsula-protected) |
| Edgewater | enr.electionsfl.org | ok | ok | election id |
| Joliet Twp | results.enr.clarityelections.com/IL/Will | ok (empty election list) | ok | Will may publish elsewhere; verify |
| Chouteau, Granite City, Nameoki, Venice twps | results.enr.clarityelections.com/IL/Madison | ok | ok | election id; adapter switch to clarity |
| Bloomington | results.enr.clarityelections.com/IL/Bloomington | ok | ok | election id; adapter switch to clarity |
| Morgan County | results.gbsvote.com | ok | ok | election id |
| El Dorado, Emporia, Ottawa | CivicPlus county sites | ok | ok | PDF link; parser untested on ES&S layout |
| Boulder City | elections.clarkcountynv.gov | ok | ok | nothing |
| Janesville | elections.co.rock.wi.us | ok | ok | nothing (date-pattern URL) |

## 3. Target architecture

1. **A residential runner is the primary on election night.** The only traffic the Ohio boards accept is from an ordinary network. Run the fetch loop (`R/watch.R`) on Alex's Mac every 60 to 120 seconds. It can reach all 34 sources, so it is the primary, not the fallback. GitHub Actions keeps running every five minutes as the backup for the 18 reachable sources, and stands down automatically when the Mac has pushed within the last ten minutes.
2. **Automatic URL discovery.** Every source that needs an election id or a fresh PDF link gets a discovery rule: fetch a known index page, extract the id or newest link with a regex, substitute it into the results URL. Nobody edits `sources.csv` on the night.
3. **Plausibility checks before publishing.** Registered-voter ceilings (now in hand for 28 races), monotonic precinct counts, YES plus NO at or below ballots cast. A failed check marks the race "needs review" and keeps the previous number instead of publishing a bad one.
4. **Direct sheet write-back** through a service account, so the sheet shows live numbers within a minute instead of hourly.
5. **Alerts and an ops view.** A `status.json` the dashboard renders as a small feed-health strip, and a Slack or email alert when a fetch fails twice in a row or a race still has no numbers 90 minutes after its polls close.
6. **Claude handles the exceptions, not the routine.** Before the election, a scheduled cloud session runs discovery daily and opens a pull request when a county publishes its election id or changes a page. On the night, a Claude Code session on the Mac supervises the loop and fixes parser misses (a new PDF layout, a renamed contest) as they happen, which is exactly the work that would otherwise be manual.

## 4. The work, in priority order

### P0, this week

**a. Mac reachability test (five minutes, decides the Ohio strategy).** From a Terminal on the Mac:

```
curl -sS -o /dev/null -w "%{http_code}\n" https://www.boe.ohio.gov/pickaway/election-info/election-results/
curl -sS -o /dev/null -w "%{http_code}\n" https://liveresults.boe.ohio.gov/ENR/butlerohenr/
```

Two `200`s mean the block is by network reputation and the plain R loop on the Mac will work as is. A `403` means a JavaScript challenge; the loop then needs a real browser for those hosts (the `chromote` package driving the Mac's Chrome), which is a contained addition to `fetch_text` and `fetch_file`.

**Result (Oct 16):** both returned `403`. The Ohio hosts run a JavaScript challenge, so the browser-backed fetch is required. The design is task T2 in `docs/handoff-local-session.md`.

**b. URL discovery in the pipeline.** Add `discover_url` and `discover_pattern` columns to `data/sources.csv` and a `discover_placeholders()` step in `fetch_results.R` that fills `ELECTION_ID` and `PDF_URL` before each fetch, caching results in `data/discovered.json`. Rules identified so far:

| Source | Discovery |
|---|---|
| Clarity counties (Madison, Bloomington) | `https://results.enr.clarityelections.com/IL/<County>/elections.json?v=1` returns a JSON list with `EID`, `ElectionName` and `Date` (verified Oct 16 for both; Madison's response is gzip-compressed, so fetch with compression on); pick the row dated 11/3/2026. Will County's list is empty, so Will needs its own answer |
| LA County | the JSON endpoint is reachable; the election list page is Incapsula-protected, so iterate ids upward from the June id (4338) until one reports the Nov 3 election, or read the id from the Mac |
| Volusia (VR Systems) | the old `vrcdn.electionsfl.org/StaticPages/volusia.html` landing page now redirects to a state directory, so discovery has to start from `enr.electionsfl.org/VOL/` or the Volusia SOE results page and take the newest `/VOL/<id>/` link |
| Morgan County (GBS) | the county clerk page links `county_results.asp?id=<id>`; the GBS home page has no list |
| Franklin OH ENR | the `franklinohenr/` index; take the highest `index_<n>.html` |
| Butler and Lucas OH ENR | same pattern on `liveresults.boe.ohio.gov`, from the Mac only |
| Ohio boe.ohio.gov counties | newest PDF link on the election-results page whose name matches cumulative, summary or results, from the Mac only |
| Delaware OH | newest `/wp-content/uploads/2026/11/*.pdf` on the home page |
| Trumbull OH | newest PDF under the 2026 heading on `boe_results.html` |
| Kansas counties | newest DocumentCenter link containing `Election-Results` or `Results` and `2026` on the clerk page (Franklin KS names them `Official-Election-Results-2026-Primary_COMPLETE`) |
| Huron OH | the home page already lists placeholder links for Nov 3 unofficial results, from the Mac only |

**c. Switch the Illinois sources to Clarity.** Madison County's clerk page links to `results.enr.clarityelections.com/IL/Madison/`, and Bloomington's past-results page links `IL/Bloomington/<id>`. Both are reachable from Actions and the Clarity adapter already parses summary.zip and summary.json. That moves five races from "no feed" to automatic. Will County needs a check: its results.enr election list is empty and its connect site returns 404, so confirm where the clerk will publish on Nov 3.

**d. Service-account write-back.** Create a Google Cloud service account, share the sheet with it as Editor, add `GOOGLE_SA_JSON` and `RESULTS_SHEET_ID` as repository secrets (and as environment secrets in the Claude cloud environment for testing). `R/write_sheet.R` already does the rest.

**e. Dress rehearsal against the May 2026 primary.** Run every adapter against that election's artifacts (Butler ENR /23/, LA County 4338, Bloomington 126005, Rock County 20260407.html, the May PDFs for Lake, Delaware, Trumbull, Clark's primary ENR, Madison's primary on Clarity). Save the fetched files as test fixtures so `R/tests` prove each parser on real layouts, not synthetic ones. This is where the PDF parser (currently "first 15 lines after the heading") gets hardened per vendor: Triad's `YYYYMMDDresults.pdf` for the boe.ohio.gov counties, Hart for Delaware, ES&S for Kansas.

### P1, by Oct 30

**f. Harden the Mac loop.** `watch.R` gains `git pull --rebase` before push, a lock file, exponential backoff on failures, a log file, and a `launchd` plist with `caffeinate` so it survives the lid closing. If step a returned 403, add the `chromote` browser fetch for the Ohio hosts.

**g. Make Actions fast and polite.** Build the R environment into a cached Docker image (`rocker/r-ver` plus the packages) or use `renv` with the actions cache so a run takes about 30 seconds instead of three minutes. Add a guard: skip the run if the Mac loop pushed `results.json` within the last ten minutes. Widen the cron to Nov 3 through Nov 6 for late canvass updates.

**h. Plausibility checks, status and alerts.** Implement the checks from section 3 in `derive_fields`. Write `site/data/status.json` with per-race adapter, last success, last error and a check result; render it as a feed-health strip on the dashboard. Add a Slack webhook (or email via the Actions failure notification) for repeated failures and for "no numbers 90 minutes after close".

**i. Registered voters into the registry.** Put the 28 counts now on the sheet into `data/races.csv` so the dashboard can show turnout against registration and the plausibility check has its ceiling. Upper Sandusky, Morgan County, Joliet Township, the Madison townships and the three Kansas cities are still missing.

### P2, nice to have

**j. Shave deploy latency.** Have the loop push `results.json` to a CDN-fronted store (a Cloudflare R2 bucket or a GitHub gist) and let the dashboard poll that every 30 seconds, skipping the Pages deploy. Keep the commit trail for history.

**k. Claude scheduled tasks.** From Oct 20, a daily cloud session (Sonnet 5.5 is plenty) runs the probe and discovery in dry-run, diffs against `data/discovered.json`, and opens a pull request when a county publishes its election id or a page changes shape. Hourly on Nov 2 and 3. On election night, a Claude Code session on the Mac with `/loop` watches the loop's log and the status file and repairs misses. Fable 5.1 for that session, since it is judgment work on unfamiliar PDFs.

**l. Cloud environment.** Add a SessionStart hook that installs R and the packages so every cloud session can run the tests and the pipeline at once (today it is a manual `apt-get`). Add the two sheet secrets. The network allowlist is already wide enough; it is not the constraint.

## 5. What "done" looks like

With P0 and P1 complete: 18 races update automatically from both Actions and the Mac; 16 Ohio races update automatically from the Mac. No routine data entry on the night. The manual sheet stays as the override for the exceptions, and the supervising Claude session handles parser misses before anyone has to open the sheet. The remaining single point of failure is the Mac itself, which is why Actions stays on as the backup for everything it can reach and why the sheet remains in the loop.
