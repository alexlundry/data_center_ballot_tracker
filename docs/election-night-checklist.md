# Election night: where each result comes from (Nov 3, 2026)

44 measures on the Nov 3 ballot:

- **15 Ohio races from 10 county files you save into the drop folder** (section 1).
- **12 races you key into the sheet by hand** (section 2): the 8 Maine towns, the 3 Kansas cities, and Monroeville OH.
- **17 races that read automatically** (section 3). Spot-check them, and key in any that stay at "No results posted" after the county has posted.

The drop folder is the Google Drive folder **Data Center Tracker / Election Night Drop**. `make drop` lists which races still have no file.

## 1. Drop folder: Ohio county files (polls close 7:30 pm ET)

For each county:

1. Open the link in your normal browser.
2. Save the **cumulative or summary** results into the drop folder. Any filename works: the loop matches files to races by the contest text inside them, and the newest matching file wins. You don't need to delete older files.
3. Skip anything named "precinct" or "detail"; the loop ignores those.
4. Save again whenever the county posts an update.

**Two kinds of file:**

- **PDF counties.** The county page links its file as `…/c/elecres/20261103results.pdf`. The direct links below are the same files; if one gives "page not found", use the county page.
- **Results-site counties (Butler, Lucas, Franklin).** Wait until the contest list has loaded, then use File > Save Page As > "Webpage, Complete".

| County | Races in the file | Where to get it | Contest to look for |
|---|---|---|---|
| Adams | Sprigg Township, Monroe Township | [county page](https://www.boe.ohio.gov/adams/election-info/election-results/) · [PDF](https://www.boe.ohio.gov/adams/c/elecres/20261103results.pdf) | "Township of Sprigg Proposed Zoning Plan", "Township of Monroe Proposed Zoning Plan" (For / Against the Zoning Resolution) |
| Ashtabula | Conneaut | [county page](https://www.boe.ohio.gov/ashtabula/election-info/election-results) · [PDF](https://www.boe.ohio.gov/ashtabula/c/elecres/20261103results.pdf) | Issue 10, City of Conneaut Charter Amendment (Data Centers) |
| Butler | Trenton | [ENR page](https://liveresults.boe.ohio.gov/ENR/butlerohenr/24/en/Index_24.html) (save as webpage) | ISSUE 17 CITY OF TRENTON |
| Champaign | Urbana | [county page](https://www.boe.ohio.gov/champaign/) · [PDF](https://www.boe.ohio.gov/champaign/c/elecres/20261103results.pdf) | City of Urbana charter amendment (section 8.07) |
| Clinton | Wilmington parcels 1–4 | [county page](https://www.boe.ohio.gov/clinton/election-info/election-results/) · [PDF](https://www.boe.ohio.gov/clinton/c/elecres/20261103results.pdf) | Ordinances O-26-04 (1), O-26-06 (2), O-26-07 (3), O-26-05 (4) |
| Defiance | Defiance | [county page](https://www.boe.ohio.gov/defiance/election-info/election-results/) · [PDF](https://www.boe.ohio.gov/defiance/c/elecres/20261103results.pdf) | City of Defiance charter amendment (section 1.12) |
| Franklin | Grove City | [Franklin's 2026 page](https://vote.franklincountyohio.gov/election-info/2026), then its results link (save as webpage, or save the summary PDF) | Issue 28, Grove City charter amendment (community consent) |
| Licking | Pataskala, Granville | [county page](https://www.boe.ohio.gov/licking/election-info/election-results/) · [PDF](https://www.boe.ohio.gov/licking/c/elecres/20261103results.pdf) | Pataskala charter amendment (11.09); Granville charter amendment (10.12) |
| Lucas | Oregon | [ENR page](https://liveresults.boe.ohio.gov/ENR/lucasohenr/23/en/Index_23.html) (save as webpage) | 25. Oregon Prohibition of Construction of a Data Center |
| Wyandot | Upper Sandusky | [county page](https://www.boe.ohio.gov/wyandot/election-info/election-results) · [PDF](https://www.boe.ohio.gov/wyandot/c/elecres/20261103results.pdf) | City of Upper Sandusky charter amendment (section 17.13) |

**Notes:**

- **Adams:** the zero report you saved at 1:39 pm is already in the folder; a newer download replaces it automatically.
- **Adams has no precinct count,** so Sprigg and Monroe will show "partly counted" until you enter the final numbers in the sheet with `override = TRUE` and `status = final`.
- **Butler and Lucas ENR folders:** the folder pages on their own say "Forbidden"; the Index links above are the election pages.

## 2. Manual entry in the sheet (no file the loop can read)

Use the `manual_results` tab of the Google Sheet:

- Fill `yes_votes` and `no_votes` exactly as the town or county labels them. Never flip them; the dashboard works out restrict and allow.
- Add the precincts if given, plus `as_of`, `source_url` and `entered_by`.
- Set `override = TRUE`.
- Set `status = final` once the count is complete.
- To tell readers when a count is coming (for example "Town office reopens Thursday"), type one sentence in `public_note` (column Z).

### Maine towns (polls close 8 pm ET; town clerks count and post their own)

| Town | Ballot item | Where to go | When to expect it |
|---|---|---|---|
| Brownfield | Question 1 | [town warrants and reports](https://www.brownfieldmaine.gov/1196/Past-Town-Warrants-Reports) | Hand-counted paper ballots; the town has not posted past results online, so the count may come only from the town office |
| Eliot | Question 5 | [election and town meeting results](https://www.eliotme.gov/304/Election-Town-Meeting-Results) | Usually election night (Nov 2025's count went up about 9:45 pm) |
| Freedom | Temporary moratorium on data centers | [town site](https://www.freedomme.org/) | No results page; the count comes from the town clerk |
| North Berwick | Question 2 | [town meeting and elections](https://www.townofnorthberwick.org/355/Town-Meeting-Elections) | Usually the morning after |
| Peru | Article 2 | [town elections posts](https://townofperumaine.org/category/elections/) | Town office closed Nov 3, reopens Thursday Nov 5; June's results went up nine days after that vote |
| Sabattus | 180-day moratorium on data centers | [election information](https://sabattus.org/election-information) | June's results went up shortly after midnight |
| Wells | Article 5 | [election results](https://wellstown.org/1122/Election-Results) | Usually the morning after |
| Wiscasset | Question 2 | [town clerk elections](https://www.wiscasset.gov/192/Town-Clerk-Elections) | Unofficial results usually the morning after |

### Kansas (polls close 8 pm ET; county clerks post PDFs the loop has no link for)

| City | Ballot item | Where to go |
|---|---|---|
| Emporia (Lyon County) | Ballot Question 2 | [Lyon County 2026 General Election Results](https://www.lyoncountyks.gov/350/2026-General-Election-Results) |
| El Dorado (Butler County KS) | Ten-year ban on high-impact data centers and large battery storage | [Butler County election results](https://www.bucoks.gov/448/Election-Results) |
| Ottawa (Franklin County KS) | Ban on data centers over 25 MW | [Franklin County election results](https://www.franklincoks.org/1067/Election-Results) |

### Ohio: Monroeville (Huron County)

| Village | Ballot item | Where to go | Why manual |
|---|---|---|---|
| Monroeville | Advisory Election (YES = allow) | [Huron County Board of Elections](https://www.huron.boe.ohio.gov/) | Huron posts a scanned image even on election night, so there is no text for the loop to read |

## 3. Automatic (nothing to download; spot-check against the county page)

The Clarity races (Bloomington, Joliet, the four Madison townships and Downe) update only from the Mac loop: Clarity blocks GitHub Actions.

| Race | Source | Link | Note |
|---|---|---|---|
| Edgewater FL | Volusia, Enhanced Voting | [results](https://app.enhancedvoting.com/results/public/volusia-county-fl/elections/2026GeneralElection) | Amendment 4 - Edgewater; polls close 7 pm |
| Ashville OH | Pickaway, Enhanced Voting | [results](https://app.enhancedvoting.com/results/public/pickaway-county-oh/GE2026_20261028170048) | Referendum on Resolution, Ashville Village |
| Hubbard OH | Trumbull PDF | [Trumbull results](https://boe.co.trumbull.oh.gov/boe_results.html) | The PDF link is found automatically once posted |
| Sunbury OH | Delaware PDF | [Delaware BOE](https://vote.delawarecountyohio.gov/) | Same: link found once posted |
| Perry OH | Lake PDF | [Lake results](https://www.lakecountyohio.gov/boe/election-results/) | Issue 16; Lake replaces the same PDF on the night |
| Bloomington IL | Clarity | [results](https://results.enr.clarityelections.com/IL/Bloomington/127392/) | Advisory data center moratorium |
| Joliet Township IL | Clarity (Will) | [results](https://results.enr.clarityelections.com/IL/Will/127394/) | Joliet Township referenda, data center |
| Chouteau, Granite City, Nameoki, Venice Twps IL | Clarity (Madison) | [Madison County results](https://www.madisoncountyil.gov/departments/county_clerk/elections/election_results.php) | Four township data center questions |
| Morgan County IL | GBS | [Morgan County clerk](https://morgancounty-il.com/wp/departments/county-clerk/) | Election id found once GBS lists Nov 3 |
| Downe Township NJ | Clarity (Cumberland) | [results](https://results.enr.clarityelections.com/NJ/Cumberland/127562/web.345435/#/summary) | Provisional ballots added in the days after |
| Harwood ND | ND Secretary of State | [results](https://resultsnd.sos.nd.gov/#election=348) | |
| Janesville WI | Rock County page | [results](https://elections.co.rock.wi.us/20261103.html) | Polls close 9 pm; absentees may post separately |
| Boulder City NV | Clark County | [results](https://elections.clarkcountynv.gov/ElectionResultsTV/ENR.aspx) | Polls close 10 pm; reader unproven until numbers post; mail ballots added for days |
| Alhambra CA | LA County | [results](https://results.lavote.gov/election-list) | Measure DB; polls close 11 pm; mail ballots added for weeks |

For Alhambra and Boulder City, "all precincts in" still leaves mail ballots, so they stay under Still out until you mark them `final` in the sheet.
