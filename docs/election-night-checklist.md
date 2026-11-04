# Election night: what you need to do (Nov 3, 2026)

Updated 10:30 pm ET. Of the 45 measures, **10 are complete, 18 are partly counted and 17 have no results yet** (8 of those are the Maine towns). The loop reads 33 on its own. This page lists only what needs you:

1. **Save files:** none needed. Every county is read straight from its own site; the drop folder stays as the fallback.
2. **Enter 12 races by hand**: the 8 Maine towns, El Dorado and Ottawa KS, Monroeville, and Upper Sandusky (done; Wyandot posts scans).
3. **Watch 5 automatic races** whose counties haven't posted, and enter one by hand if it stays blank.
4. **Check each race's first numbers once** against the county page.
5. **Mark races final** when their counts are complete, because 18 of them can't finish on their own.

## How to enter a race in the sheet

Use the `manual_results` tab of the [Google Sheet](https://docs.google.com/spreadsheets/d/1jma2RqwyFNB8dP23f0nM4LCRti54uBJBoqEIktR9fRs/edit), on the race's row:

- Type `yes_votes` and `no_votes` exactly as the county or town labels them. Never flip them; the dashboard works out restrict and allow.
- Fill `as_of`, `source_url` and `entered_by`, plus the precincts if given.
- `override` is already TRUE on every row, so your numbers replace the feed on the next pass (about two minutes). To hand a race back to the feed, clear its numbers.
- Set `status = final` once the count is complete.
- To tell readers when a count is coming (for example "Town office reopens Thursday"), type one sentence in `public_note` (column Z).

## 1. Save files to the drop folder (none needed)

Every county with a readable file is read directly: Adams, Ashtabula, Butler (its summary PDF), Champaign, Clinton, Defiance, Licking, Lucas (its precinct CSV) and Lake from boe.ohio.gov or the county; Delaware from its summary PDF; Franklin from its new [live results viewer](https://vote.franklincountyohio.gov/elections). The drop folder (Google Drive, **Data Center Tracker / Election Night Drop**) is the fallback: save a county's file there only if its race stops updating. The loop uses whichever file is newer, the county's or yours.

## 2. Enter by hand (12 races)

### Maine towns (polls closed 8 pm ET; each town counts and posts its own)

Nothing posted anywhere as of 9:45 pm, including the local papers. The dashboard tells readers the towns usually post a day or more after the polls close.

| Town | Ballot item | Where to go | When to expect it |
|---|---|---|---|
| Eliot | Question 5 | [election and town meeting results](https://www.eliotme.gov/304/Election-Town-Meeting-Results) | Often election night (Nov 2025's went up about 9:45 pm), sometimes the next day |
| Sabattus | Data Center Moratorium | [election information](https://sabattus.org/election-information) | June's went up shortly after midnight |
| North Berwick | Question 2 | [town meeting and elections](https://www.townofnorthberwick.org/355/Town-Meeting-Elections) | Usually the morning after |
| Wiscasset | Question 2 | [town clerk elections](https://www.wiscasset.gov/192/Town-Clerk-Elections) | Usually the morning after, as PDFs in the town's Document Center |
| Wells | Article 5 | [election results](https://wellstown.org/1122/Election-Results) | Usually the next day |
| Brownfield | Question 1 | [town warrants and reports](https://www.brownfieldmaine.gov/1196/Past-Town-Warrants-Reports) | Posts on this page (Oct 2025's went up the next day); if nothing is posted, call 207-935-2007 |
| Freedom | Temporary moratorium on data centers | [town site](https://www.freedomme.org/) | No results page; the count comes from the town clerk |
| Peru | Article 2 | [town elections posts](https://townofperumaine.org/category/elections/) | Town office reopens Thursday Nov 5; June's results took nine days |

Local papers sometimes beat the towns: the Bangor Daily News, the Sun Journal (Sabattus), the Wiscasset Newspaper, and Seacoast Online or the York County Coast Star (Eliot, Wells, North Berwick).

### Kansas: El Dorado and Ottawa (polls closed 8 pm ET)

Neither county had linked any Nov 3 results as of 10:16 pm. Emporia and Americus are automatic: the loop picks up each new "Unofficial … November 3, 2026" PDF on Lyon County's page (four so far).

| City | Ballot item | Where to go |
|---|---|---|
| El Dorado (Butler County KS) | Ten-year ban on high-impact data centers and large battery storage | [Butler County election results](https://www.bucoks.gov/448/Election-Results) |
| Ottawa (Franklin County KS) | Ban on data centers over 25 MW | [Franklin County election results](https://www.franklincoks.org/1067/Election-Results) |

If either county posts a text PDF at a stable address, tell Claude: setting that race's `api_url` lets the loop read it.

### Ohio: Monroeville (Huron County)

Huron's home page lists "November 3, 2026 General Election UNOFFICIAL Results", but as of 10:17 pm it was a placeholder with no link behind it. Huron posts scanned images, so enter Monroeville from [Huron's site](https://www.huron.boe.ohio.gov/) when it appears. Advisory question; YES = allow.

### Ohio: Upper Sandusky (Wyandot County): done

Entered at 9:38 pm from Wyandot's scanned 8:55 pm report: YES 1,893, NO 568, 6 of 6 precincts, shown as complete. Retype the numbers only if Wyandot posts an update before the canvass.

## 3. Watch: automatic, but the county hasn't posted

| Race | Where to look | Status at 10:16 pm |
|---|---|---|
| Sprigg, Monroe Twp OH (Adams) | [Adams results page](https://www.boe.ohio.gov/adams/election-info/election-results/) | Nothing posted: the file is still the Sept 30 zero report and the precinct file is missing. The slowest Ohio county tonight; a call may be worth it. Both read automatically once Adams posts |
| Oregon OH (Lucas) | [Lucas results page](https://liveresults.boe.ohio.gov/ENR/lucasohenr/23/en/Index_23.html) | Still "Updated: 10/28/2026". If Lucas is posting elsewhere tonight (its own site, lucascountyohiovotes.gov, blocks the loop), enter Oregon by hand |
| Hubbard OH (Trumbull) | [Trumbull results](https://boe.co.trumbull.oh.gov/boe_results.html) | No Nov 3 PDF linked yet; the loop finds it once it is |
| Morgan County IL | [Morgan County clerk](https://morgancounty-il.com/wp/departments/county-clerk/) | GBS lists Morgan's elections only through March 2026, so Morgan may post elsewhere; check the clerk's site and enter by hand if needed |
| Boulder City NV | [Clark County results](https://elections.clarkcountynv.gov/ElectionResultsTV/ENR.aspx) | Page shows only "2026 General Election"; Nevada's first counts usually land after 11 pm ET. Look for "CITY OF BOULDER CITY BALLOT QUESTION NUM. 1" |

Alhambra CA reads automatically once LA County posts (polls close 11 pm ET).

## 4. First-number check (once per race)

The first time a race shows numbers, compare its YES and NO once with the county page. The sheet's `auto_yes` and `auto_no` columns sit beside the manual columns. If they differ, type the county's numbers into the sheet.

**Checked against the county's own file, page or feed:** Urbana, Conneaut, Defiance, Perry Village, Edgewater, Ashville, Trenton (8 of 8, 3,522 to 902 on Butler's page), Emporia, Americus, Sunbury, Pataskala, Granville, Upper Sandusky, Wilmington parcels 1–4, Janesville (10,474 to 6,286 on Rock County's page) and Harwood (North Dakota's data: Yes 75, No 242).

**Read from the county's own Clarity feed** (contest and YES/NO checked at zero): Bloomington, Joliet Township, Downe, and the four Madison townships.

**Still to check:**

| Race | Compare with |
|---|---|
| Grove City | [Franklin's live results viewer](https://vote.franklincountyohio.gov/elections) (#28; the loop adds up Franklin's precinct totals) |
| Wilmington 1–4, each update | [Clinton's PDF](https://www.boe.ohio.gov/clinton/c/elecres/20261103results.pdf). It's a scan run through text recognition, so check each YES + NO equals its Total row |
| Sprigg, Monroe Twp, Oregon, Hubbard, Morgan County, Boulder City | Step 3, once posted |
| Alhambra CA | [LA County](https://results.lavote.gov/election-list), Measure DB |

## 5. Mark final when the count is complete

**Complete on their own (no action):** Urbana, Defiance, Trenton, Ashville, Perry Village, Upper Sandusky, and the Chouteau, Granite City, Nameoki and Venice townships. Sunbury, Bloomington, Joliet Township and Harwood will complete on their own too, because their counties report precincts.

These can't finish on their own. Once the county's count is complete, type its final YES and NO in the sheet and set `status = final`:

- **No precinct line:** Grove City, Conneaut, Pataskala, Granville, Sprigg, Monroe Township, Edgewater, Oregon, Emporia, Americus, Downe, and Wilmington parcels 1–4.
- **Stuck precinct line:** Janesville. Rock County's own page says "0 of 40 precincts" while listing every ward's count.
- **Late counting:** Alhambra (mail ballots for weeks) and Boulder City (mail ballots for days). Mark these final only when the county finishes.
- **The hand-entered races** (step 2), once each count is complete.

## If something goes wrong

- **A race stops updating:** check the county page. Save its file to the drop folder, or type the numbers into the sheet.
- **A count looks wrong:** type the county's numbers into the sheet. Your numbers win until you clear them.
- **Clarity errors (Illinois and Downe):** Clarity's servers have answered with 500, 502 and 504 errors on and off since about 8:34 pm. The loop keeps each race's last numbers and catches up when Clarity answers.
- **A county file goes wrong:** at 8:48 pm Licking's file briefly held Tuscarawas County's report. The loop now keeps the last good numbers when a county's file is older or unreadable, and ignores a precinct count higher than the total (Butler printed Trenton as "82 of 8" at 9:06 pm).
- **Direct county files misbehave:** stop the loop with Ctrl-C in its terminal, then restart it with `DCBT_DIRECT=0 Rscript R/watch.R 120`. It goes back to reading only the drop folder.
- **The loop stops:** restart it with `caffeinate -i Rscript R/watch.R 120` from the repo folder.
