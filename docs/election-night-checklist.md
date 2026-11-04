# Election night: what you need to do (Nov 3, 2026)

Updated 12:15 am ET Nov 4. Of the 45 measures, **29 are complete, 5 are partly counted and 11 have no results yet** (6 of those are the Maine towns). This page lists only what still needs you:

1. **Enter 7 races by hand** when their counts appear: six Maine towns and Morgan County IL.
2. **Swap 2 news counts for official ones:** Peru (Sun Journal) and Hubbard (WFMJ).
3. **Watch 4 automatic races** whose counties haven't posted: Sprigg, Monroe Township, Oregon and Boulder City.
4. **Mark 8 races final** once their counts stop changing: Grove City, Ottawa, Downe and Alhambra now, then the four in step 3 once they post.

## How to enter a race in the sheet

Use the `manual_results` tab of the [Google Sheet](https://docs.google.com/spreadsheets/d/1jma2RqwyFNB8dP23f0nM4LCRti54uBJBoqEIktR9fRs/edit), on the race's row:

- Type `yes_votes` and `no_votes` exactly as the county or town labels them. Never flip them; the dashboard works out restrict and allow.
- Fill `as_of`, `source_url` and `entered_by`, plus the precincts if given. A one-precinct town entered as 1 of 1 shows as complete.
- `override` is already TRUE on every row, so your numbers replace the feed on the next pass (about two minutes). To hand a race back to the feed, clear its numbers and status.
- Set `status = final` once the count is complete.
- To tell readers when a count is coming (for example "Town office reopens Thursday"), type one sentence in `public_note` (column Z).

## 1. Enter by hand (7 races)

### Maine towns

Eliot and Peru are in. Nothing else had posted at 11 pm, on the town sites or in the papers. The dashboard tells readers the towns usually post a day or more after the polls close.

| Town | Ballot item | Where to go | When to expect it |
|---|---|---|---|
| Sabattus | Data Center Moratorium | [election information](https://sabattus.org/election-information) | June's went up shortly after midnight; also facebook.com/sabattus.town |
| North Berwick | Question 2 | [town meeting and elections](https://www.townofnorthberwick.org/355/Town-Meeting-Elections) | Usually the morning after |
| Wiscasset | Question 2 | [town clerk elections](https://www.wiscasset.gov/192/Town-Clerk-Elections) | Usually the morning after, as PDFs in the town's Document Center |
| Wells | Article 5 | [election results](https://wellstown.org/1122/Election-Results) | Usually the next day |
| Brownfield | Question 1 | [town warrants and reports](https://www.brownfieldmaine.gov/1196/Past-Town-Warrants-Reports) | The next day; if nothing is posted, call 207-935-2007 |
| Freedom | Temporary moratorium on data centers | [town site](https://www.freedomme.org/) | No results page; call the clerk, Cindy Abbott, 207-382-6177 |

Eliot posted its return in its Document Center before its results page linked it. The other towns' sites work the same way, so a file can be up before the page shows it. Claude can check the newest document numbers. Local papers sometimes beat the towns: the Sun Journal (Sabattus), the Wiscasset Newspaper, and Seacoast Online or the York County Coast Star (Wells, North Berwick).

### Morgan County IL

Nothing posted anywhere as of midnight. GBS, the county's past results site, lists no Nov 3 election, and WLDS and the Journal-Courier had no result. Check the [county clerk](https://morgancounty-il.com/wp/departments/county-clerk/) in the morning and enter it by hand. Advisory question; YES = restrict.

## 2. Swap news counts for official ones

| Race | Entered from | Replace when |
|---|---|---|
| Peru ME (578 to 182) | The Sun Journal's 10:30 pm story | The town posts its own count. The office reopens Thursday Nov 5 at 8 am (clerk 207-562-4627) |
| Hubbard OH (2,622 to 802, final) | WFMJ's results page, 100% reported at 10:11 pm | Trumbull posts its own file on its [results page](https://boe.co.trumbull.oh.gov/boe_results.html); nothing there at midnight |

## 3. Watch: automatic, but the county hasn't posted

| Race | Status at midnight | What happens next |
|---|---|---|
| Sprigg, Monroe Twp OH (Adams) | The [results file](https://www.boe.ohio.gov/adams/election-info/election-results/) is still the Sept 30 zero report. Adams has reported its statewide races to the Secretary of State | The loop reads both as soon as Adams replaces the file. Or call the board, (937) 544-2633 or 544-5111. Neither race has a precinct line, so each needs a manual final |
| Oregon OH (Lucas) | Lucas hasn't reported any local race; 13abc shows every Lucas contest at zero. The precinct file is unchanged since Oct 28 | The loop reads Lucas's precinct CSV when the county updates it ([results page](https://liveresults.boe.ohio.gov/ENR/lucasohenr/23/en/Index_23.html)). No precinct line, so it needs a manual final |
| Boulder City NV | Nevada had released nothing statewide at 12:05 am ET (0 of 17 counties) | The loop reads [Clark County's page](https://elections.clarkcountynv.gov/ElectionResultsTV/ENR.aspx) once it posts. Mail ballots count through Nov 7 and cures through Nov 9, so mark it final only when Clark finishes |

## 4. Mark final when the count stops changing

| Race | Now | Why it isn't final yet |
|---|---|---|
| Grove City | 11,317 to 9,411 | Every precinct is in, but Franklin was still adding absentee ballots at 11:52 pm. Mark final once [Franklin's viewer](https://vote.franklincountyohio.gov/elections) stops moving |
| Ottawa KS | 2,882 to 1,129 | Franklin County KS's graphic gives no precinct count. Confirm the count is complete, then mark final. A court order stays the ordinance regardless of the outcome |
| Downe Township NJ | 62 to 425 | Clarity was stuck at 16 to 97 until about midnight, then jumped. It stalled short of all precincts in Nov 2025; if it stops, enter the clerk's count from [cumberlandcountyclerknj.gov](https://cumberlandcountyclerknj.gov/election-information/election-results/) |
| Alhambra CA | 10,177 to 2,171 | LA County counts mail ballots for weeks. Mark final only at certification |
| Sprigg, Monroe Twp, Oregon, Boulder City | No results | See step 3 |

Harwood ND (105 to 325) completes on its own when North Dakota marks its precinct fully reported. So does each Maine town you enter as 1 of 1. Give Morgan County its precinct count when you enter it, or mark it final.

## Done (no action)

- **Complete on their own (12):** Bloomington, Joliet Township, the Chouteau, Granite City, Nameoki and Venice townships, Ashville, Defiance, Perry Village, Trenton, Urbana and Janesville.
- **Entered by hand (5):** Upper Sandusky, Monroeville and Sunbury (from county scans and Delaware's results feed), plus Eliot and Peru.
- **Marked final (12):** Hubbard, El Dorado, Conneaut, Pataskala, Granville, Wilmington parcels 1–4, Emporia, Americus and Edgewater.

Hand-entered numbers stay pinned until you clear them. Ohio adds provisional and late mail ballots at its official canvass later in November; retype a race then if you want the certified count.

## Tomorrow, for a Claude session

Two counties changed their results source on election night, so the loop could not follow them:
- **Sunbury:** Delaware replaced its summary PDF with a scan. Its results feed (`boeresults.delco-gis.org/boe/api/results`, NIST format) has the count.
- **El Dorado:** Butler County KS moved to `livevoterturnout.com/ENR/butlerksenr/4`, the same results system as Ohio's state site.

Hubbard's county posts nowhere the loop can read, and Ottawa's posts a graphic.

## If something goes wrong

- **A race stops updating:** check the county page, then save its file to the drop folder or type the numbers into the sheet.
- **A count looks wrong:** type the county's numbers into the sheet. Your numbers win until you clear them.
- **Clarity errors (Illinois and Downe):** the loop keeps each race's last numbers and catches up when Clarity answers.
- **Direct county files misbehave:** stop the loop with Ctrl-C in its terminal, then restart it with `DCBT_DIRECT=0 Rscript R/watch.R 120`. It goes back to reading only the drop folder.
- **The loop stops:** restart it with `caffeinate -i Rscript R/watch.R 120` from the repo folder.
