# Election night: what you need to do (Nov 3, 2026)

Updated 8:40 pm ET. Of the 45 measures, the loop reads 31 on its own. This page lists only what needs you:

1. **Save files** for 1 Ohio county (Franklin).
2. **Enter 13 races by hand**: the 8 Maine towns, the 4 Kansas cities, and Monroeville.
3. **Watch 6 automatic races** and enter one by hand if it stays blank after the county posts.
4. **Check each race's first numbers once** against the county page.
5. **Mark 10 races final** when their counts are complete, because they cannot finish on their own.

## How to enter a race in the sheet

Use the `manual_results` tab of the Google Sheet, on the race's row:

- Type `yes_votes` and `no_votes` exactly as the county or town labels them. Never flip them; the dashboard works out restrict and allow.
- Fill `as_of`, `source_url` and `entered_by`, plus the precincts if given.
- `override` is already TRUE on every row, so your numbers replace the feed on the next pass (about two minutes). To hand a race back to the feed, clear its numbers.
- Set `status = final` once the count is complete.
- To tell readers when a count is coming (for example "Town office reopens Thursday"), type one sentence in `public_note` (column Z).

## 1. Save files to the drop folder (1 Ohio county)

The drop folder is the Google Drive folder **Data Center Tracker / Election Night Drop**. Any filename works, and the newest file wins. Save again each time the county updates. `make drop` lists races with no file yet.

| County | Race | Where | What to save | Contest |
|---|---|---|---|---|
| Franklin | Grove City | [Franklin's 2026 page](https://vote.franklincountyohio.gov/election-info/2026), then its results link | The results page as "Webpage, Complete", or the summary PDF | Issue 28, Grove City charter amendment |

**No longer needed:** Adams, Ashtabula, Butler, Champaign, Clinton, Defiance, Licking, Lucas and Wyandot. The loop reads their files straight from the county (Butler's summary PDF since 8:26 pm, Lucas's precinct CSV since 8:36 pm) and uses whichever file is newer, the county's or yours. Save one only if its race stops updating.

## 2. Enter by hand (13 races)

### Maine towns (polls close 8 pm ET; town clerks count and post their own)

| Town | Ballot item | Where to go | When to expect it |
|---|---|---|---|
| Brownfield | Question 1 | [town warrants and reports](https://www.brownfieldmaine.gov/1196/Past-Town-Warrants-Reports) | Posts results on this page (Oct 2025's went up the next day); if nothing is posted, call 207-935-2007 |
| Eliot | Question 5 | [election and town meeting results](https://www.eliotme.gov/304/Election-Town-Meeting-Results) | Often election night (Nov 2025's went up about 9:45 pm), sometimes the next day |
| Freedom | Temporary moratorium on data centers | [town site](https://www.freedomme.org/) | No results page; the count comes from the town clerk |
| North Berwick | Question 2 | [town meeting and elections](https://www.townofnorthberwick.org/355/Town-Meeting-Elections) | Usually the morning after |
| Peru | Article 2 | [town elections posts](https://townofperumaine.org/category/elections/) | Town office reopens Thursday Nov 5; June's results took nine days |
| Sabattus | Data Center Moratorium | [election information](https://sabattus.org/election-information) | June's went up shortly after midnight |
| Wells | Article 5 | [election results](https://wellstown.org/1122/Election-Results) | Usually the next day |
| Wiscasset | Question 2 | [town clerk elections](https://www.wiscasset.gov/192/Town-Clerk-Elections) | Usually the morning after, as PDFs in the town's Document Center |

### Kansas (polls close 8 pm ET; no Nov 3 results linked as of 7:20 pm)

| City | Ballot item | Where to go |
|---|---|---|
| Emporia (Lyon County) | Ballot Question 2 | [Lyon County 2026 General Election Results](https://www.lyoncountyks.gov/350/2026-General-Election-Results) |
| Americus (Lyon County) | Ordinance prohibiting High Impact Data Centers and Tier 2/3 battery storage | Same Lyon County page |
| El Dorado (Butler County KS) | Ten-year ban on high-impact data centers and large battery storage | [Butler County election results](https://www.bucoks.gov/448/Election-Results) |
| Ottawa (Franklin County KS) | Ban on data centers over 25 MW | [Franklin County election results](https://www.franklincoks.org/1067/Election-Results) |

If a county posts a text PDF at a stable address, tell Claude: setting that race's `api_url` lets the loop read it.

### Ohio: Monroeville (Huron County)

| Village | Ballot item | Where to go |
|---|---|---|
| Monroeville | Advisory Election (YES = allow) | [Huron County Board of Elections](https://www.huron.boe.ohio.gov/). Huron posts scanned images, so the loop can't read them |

## 3. Watch these; enter by hand if one stays blank after the county posts

| Race | Where to look | Why it might not read |
|---|---|---|
| Sunbury OH (Delaware) | [Delaware live results](https://boeresults.delco-gis.org/) or [Delaware BOE](https://vote.delawarecountyohio.gov/) | Delaware's zero report was a scanned PDF. Its live site's data feed carries "City of Sunbury - Proposed Charter Amendment", and Claude can build a reader for it once counts appear |
| Oregon OH (Lucas) | [Lucas results page](https://liveresults.boe.ohio.gov/ENR/lucasohenr/23/en/Index_23.html) | At 8:30 pm the page still said "Updated: 10/28/2026" with every race at 0. If Lucas posts somewhere else tonight (its own site, lucascountyohiovotes.gov, is bot-checked for the loop), enter Oregon by hand |
| Hubbard OH (Trumbull) | [Trumbull results](https://boe.co.trumbull.oh.gov/boe_results.html) | The loop finds Trumbull's PDF once it is posted; its layout is the least tested |
| Upper Sandusky OH (Wyandot) | [Wyandot results](https://www.boe.ohio.gov/wyandot/election-info/election-results) | Read directly once posted, but the contest title is a best guess ("Charter Amendment Prohibition of a Data Center") |
| Morgan County IL | [Morgan County clerk](https://morgancounty-il.com/wp/departments/county-clerk/) | The loop needs GBS to list the Nov 3 election |
| Boulder City NV | [Clark County results](https://elections.clarkcountynv.gov/ElectionResultsTV/ENR.aspx) | Clark posts about 10 pm ET. The reader was fixed today and checked only on the 2024 page; look for "CITY OF BOULDER CITY BALLOT QUESTION NUM. 1" |

## 4. First-number check (once per race)

The first time a race shows numbers, compare its YES and NO once with the county page. The sheet's `auto_yes` and `auto_no` columns sit beside the manual columns. If they differ, type the county's numbers into the sheet.

**Already checked:** Urbana, Conneaut, Defiance, Perry Village, Edgewater, Ashville and Trenton, all against the county's own file, page or feed.

**Still to check when numbers appear:**

| Race | Compare with |
|---|---|
| Sprigg, Monroe Twp (Adams) | [Adams PDF](https://www.boe.ohio.gov/adams/c/elecres/20261103results.pdf) ("For / Against the Zoning Resolution"; For is YES) |
| Pataskala, Granville (Licking) | [Licking PDF](https://www.boe.ohio.gov/licking/c/elecres/20261103results.pdf) (Pataskala is the "Data Centers" amendment, the last of four) |
| Wilmington parcels 1–4 (Clinton) | [Clinton PDF](https://www.boe.ohio.gov/clinton/c/elecres/20261103results.pdf) (O-26-04 is parcel 1, O-26-06 parcel 2, O-26-07 parcel 3, O-26-05 parcel 4) |
| Oregon | [Lucas results page](https://liveresults.boe.ohio.gov/ENR/lucasohenr/23/en/Index_23.html), contest 25 |
| Grove City | The page you save in step 1 |
| Hubbard, Sunbury, Upper Sandusky | The pages in step 3 |
| Bloomington IL | [Clarity](https://results.enr.clarityelections.com/IL/Bloomington/127392/) (showing 5,083 to 1,107 at 8:10 pm; not yet checked) |
| Joliet Township IL | [Clarity](https://results.enr.clarityelections.com/IL/Will/127394/) |
| Chouteau, Granite City, Nameoki, Venice Twps IL | [Madison County results](https://www.madisoncountyil.gov/departments/county_clerk/elections/election_results.php) |
| Morgan County IL | Step 3 |
| Downe Township NJ | [Clarity](https://results.enr.clarityelections.com/NJ/Cumberland/127562/web.345435/#/summary) |
| Harwood ND | [ND results](https://resultsnd.sos.nd.gov/#election=348) |
| Janesville WI | [Rock County](https://elections.co.rock.wi.us/20261103.html) (polls close 9 pm ET) |
| Boulder City NV | Step 3 (about 10 pm ET) |
| Alhambra CA | [LA County](https://results.lavote.gov/election-list), Measure DB (polls close 11 pm ET) |

## 5. Mark final when the count is complete

These races print no precinct count, or keep counting mail ballots for days, so they stay under "Still out" until you finish them. Once the county's count is complete, type its final YES and NO in the sheet and set `status = final`:

- **No precinct line:** Urbana, Conneaut, Pataskala, Granville, Sprigg, Monroe Township, Edgewater, Oregon.
- **Late counting:** Alhambra (mail ballots for weeks) and Boulder City (mail ballots for days). Mark these final only when the county finishes.
- **All 13 hand-entered races** (step 2), once each count is complete.

Any other race still showing "Partly counted" after its county says counting is done needs the same treatment.

## If something goes wrong

- **A race stops updating:** check the county page. Save its file to the drop folder (Ohio), or type the numbers into the sheet.
- **A count looks wrong:** type the county's numbers into the sheet. Your numbers win until you clear them.
- **Direct county files misbehave:** stop the loop with Ctrl-C in its terminal, then restart it with `DCBT_DIRECT=0 Rscript R/watch.R 120`. It goes back to reading only the drop folder.
- **The loop stops:** restart it with `caffeinate -i Rscript R/watch.R 120` from the repo folder.
