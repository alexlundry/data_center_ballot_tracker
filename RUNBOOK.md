# Election night runbook · November 3, 2026

## The week before
- [ ] Confirm every Nov 3 row in `data/races.csv` is still on the ballot. Watch items: Ottawa KS (Oct 20 hearing on whether the ordinance is legislative), Emporia KS (declaratory judgment pending), Ashville OH (council's repeal Resolution 16-2026 could pull the referendum), Upper Sandusky OH (confirmed only via secondary sources; call Wyandot BOE 419-294-1226). Set `status = removed` for anything pulled.
- [ ] Download the Ohio SOS "November 3, 2026 General Election – Local Questions and Issues (XLSX)" from https://www.ohiosos.gov/elections. Fill in `measure_label` (issue numbers) and paste the certified `ballot_text` for the 19 Ohio rows; set `ballot_text_verbatim = TRUE`.
- [ ] For each county in `data/sources.csv` marked `unverified` or `pattern`, open the county's results page from the most recent election and record: the URL pattern, whether it is HTML, PDF or an ENR vendor, and (for Scytl/Clarity or ENR sites) the JSON path visible in the browser's network tab. Update `adapter`, `api_url`, `contest_pattern`. Mark `source_status = verified`.
- [ ] Decide hosting: enable GitHub Pages (Settings > Pages > Source: GitHub Actions) or connect the repo to Netlify. Push once and confirm the site loads.
- [ ] The manual-entry Google Sheet exists (Data Center Ballot Tracker — Election Night Manual Entry, in Alex's Drive) and is wired into the `sheet` row of `sources.csv`. Before election night: set sharing to Anyone with the link > Viewer (or Publish to web) so the pipeline can read it without login, and give edit access to everyone who will key in numbers. Test with `Rscript R/fetch_results.R --dry-run`; a failure to read the sheet is logged as a warning, not a crash.
- [ ] `make reset` so `results.json` has no simulated data, then `make build`, commit, push.
- [ ] Run `Rscript R/fetch_results.R` once against the live pre-election pages. Every source should fail cleanly (no contest yet) rather than crash. Fix anything that throws.

## Election day
- 6:00 pm ET: enable the `Update results` workflow (or start `Rscript R/watch.R 120` on a laptop with push access). Check the Actions tab shows a green run.
- 7:00 pm ET: Volusia County (Edgewater) opens. 7:30 pm: all 19 Ohio measures. 8:00 pm: Kansas (3), Illinois (7), Chester County PA. 9:00 pm: Rock County WI. 10:00 pm: Clark County NV. 11:00 pm: LA County CA.
- As each county's first numbers post, open its page and compare to the dashboard card. If the card still says "No results yet":
  1. Look at the Action log (or `watch.R` output) for that `race_id`. "no contest matched" means the `contest_pattern` regex is wrong: copy the exact contest name from the page into `sources.csv`. "could not map choices" means the choice labels are not Yes/No: set `yes_pattern` / `no_pattern`.
  2. If the page is a PDF, switch `adapter` to `pdf` and put the PDF URL in `api_url`.
  3. If nothing works within a few minutes, key the numbers into the Google Sheet with `override = TRUE`. Manual beats automated. Keep updating that row as the county updates.
- Mark a race `status = final` in the sheet once the county shows 100% precincts or "final unofficial".
- Use the **Copy summary** button for a plain-text update to paste into email or Slack.

## Known soft spots
- Ohio SOS `liveresults.ohiosos.gov` carries statewide contests and State Issue 3 only (Directives 2026-22 and 2026-48; the Nov 2025 SOS review sent readers to county sites for local results). All 20 Ohio measures come from 15 county boards: Butler, Franklin and Lucas run an ENR site whose instance ID changes each election (read it off the index page at 7:30 pm); the other 12 post PDFs.
- Election IDs to collect on the night, each a placeholder `ELECTION_ID` in `data/sources.csv`: Butler OH ENR, Franklin OH ENR, Lucas OH ENR, Will County IL (Clarity), LA County (JSON), Volusia FL (VR Systems), Morgan County IL (GBS portal). Replace them with sed or a quick edit, then `make fetch`.
- Illinois: Bloomington's numbers come from the Bloomington Election Commission, not McLean County.
- Wisconsin: Janesville absentee ballots are counted centrally and may post separately from in-person totals.
- Kansas counties post PDFs; the `pdf` adapter is best-effort. Plan on manual entry for Emporia, El Dorado and Ottawa.
- GitHub's 5-minute cron can lag by 10–20 minutes on busy nights. `R/watch.R` is the fallback.
- "Votes remaining" assumes equal-size precincts. Say "estimate" if you quote it.

## After
- Disable the cron workflow. Run `make fetch` once the next morning for complete unofficial counts, set `final` on everything, and commit.
