# After election night: what still needs you (Nov 4, 2026)

Updated 9:15 am ET Nov 4, plus Piqua, Freedom, North Berwick, Morgan County and Belvidere NJ since. Of the 47 measures, **39 are complete, 6 are partly counted and 2 have no results yet** (Wiscasset and Brownfield ME). The results loop is still running on the Mac. This page lists only what still needs you:

1. **Enter 2 races by hand** when their counts appear: Wiscasset and Brownfield ME.
2. **Mark 4 races final** once their counties say the count is done: Grove City, Oregon, Ottawa and Downe.
3. **Swap 1 news count for the official one:** Peru (Sun Journal).
4. **Leave 2 late-counting races alone:** Boulder City and Alhambra update on their own for days.

## How to enter a race in the sheet

Use the `manual_results` tab of the [Google Sheet](https://docs.google.com/spreadsheets/d/1jma2RqwyFNB8dP23f0nM4LCRti54uBJBoqEIktR9fRs/edit), on the race's row:

- Type `yes_votes` and `no_votes` exactly as the county or town labels them. Never flip them; the dashboard works out restrict and allow.
- Fill `as_of`, `source_url` and `entered_by`, plus the precincts if given. A one-precinct town entered as 1 of 1 shows as complete.
- `override` is already TRUE on every row, so your numbers replace the feed on the next pass (about two minutes). To hand a race back to the feed, clear its numbers and status.
- Set `status = final` once the count is complete. To mark an automatic race final, type its current numbers into its row too; it then stays pinned there.
- To tell readers when a count is coming, type one sentence in `public_note` (column Z).

## 1. Enter by hand (2 races)

### Maine towns

Nothing had posted at 9:15 am: not on the town sites, not in their Document Centers (Claude checked past the newest file numbers), and not in the papers. Each town votes as one precinct, so enter it as 1 of 1.

| Town | Ballot item | Where to go | What to expect |
|---|---|---|---|
| Wiscasset | Question 2 | [town clerk elections](https://www.wiscasset.gov/192/Town-Clerk-Elections) | Unofficial PDFs on that page and in a news flash, usually the morning after |
| Brownfield | Question 1 | [town warrants and reports](https://www.brownfieldmaine.gov/1196/Past-Town-Warrants-Reports) | The town office is closed Wed Nov 4 and reopens Thu Nov 5 at 9 am; call 207-935-2007 then (no past ballot result is online) |

The papers sometimes beat the towns: the Wiscasset Newspaper and Lincoln County News (Wiscasset), Seacoast Online and the York County Coast Star (North Berwick), and the Bangor Daily News, which previewed all eight Maine votes.

## 2. Mark final when the county says it's done (4 races)

| Race | Now | What to look for |
|---|---|---|
| Grove City OH | 11,317 to 9,411 (Restrict 54.6%), unchanged since 11:52 pm Nov 3 | Every precinct is in. Franklin's feed still labels the count unofficial, as Ohio counties do until the canvass, and it hasn't moved in over nine hours. Marking it final now is reasonable: its row is blank (it reads the feed), so type 11,317 and 9,411 with `status = final` |
| Oregon OH | 4,994 to 3,235 (Restrict 60.7%) | Lucas's [results page](https://liveresults.boe.ohio.gov/ENR/lucasohenr/23/en/Index_23.html) (updated 2:51 am) still says "Absentee Ballots: Partially Reported". The loop adds new ballots by itself; mark final when that line says fully reported |
| Ottawa KS | 2,882 to 1,129 (Restrict 71.9%) | Franklin County KS's graphic (version _6, read at midnight) gives no precinct count, and the county has posted nothing newer. Confirm with the county clerk that the count is complete, then set `status = final` (the numbers are already in its row). A September court order stays the ordinance regardless of the outcome |
| Downe Township NJ | 62 to 425 (NO = restrict, 87.3%), unchanged since 11:58 pm Nov 3 | Clarity shows 0% of districts reporting; it stalled the same way in Nov 2025. The clerk's [results page](https://cumberlandcountyclerknj.gov/election-information/election-results/) has nothing for Nov 3 yet. When it posts, enter the clerk's count with `status = final` |

## 3. Swap the news count for the official one

| Race | Entered from | Replace when |
|---|---|---|
| Peru ME (578 to 182) | The Sun Journal's 10:30 pm story | The town posts its own count. The office reopens Thursday Nov 5 at 8 am (clerk 207-562-4627); June's results went up nine days after the vote |

Hubbard is done: Trumbull's own report (6:48 am Nov 4, linked from its home page rather than its results page) has the same 2,622 to 802, and the sheet now cites it.

## 4. Late counting: no action until the counties finish

| Race | Now | When it's done |
|---|---|---|
| Boulder City NV | NO leads 4,726 to 1,973 (NO = restrict, 70.5%) | Updates on its own. Nevada counts mail ballots arriving through Nov 7 and cures through Nov 9; mark final only when Clark finishes |
| Alhambra CA | 12,496 to 2,772 (Restrict 81.8%) | Updates on its own. LA County adds mail ballots in scheduled updates for weeks; mark final at certification |

GitHub's hourly run (Nov 5–13) keeps both moving if you stop the loop on the Mac. Downe's Clarity feed answers only the Mac, so keep the loop running until Downe is settled or hand-entered.

Each open race's `public_note` (column Z) tells readers why it is still open; update the note when a race moves.

## Done (no action): 39 complete

- **Complete on their own (13):** Bloomington, Joliet Township, the Chouteau, Granite City, Nameoki and Venice townships, Ashville, Defiance, Perry Village, Trenton, Urbana, Janesville and Harwood ND.
- **Entered by hand (11):** Upper Sandusky, Monroeville, Sunbury, Sprigg and Monroe townships in Ohio (from county scans and Delaware's results feed), and Eliot, Wells, Sabattus, Peru, Freedom and North Berwick in Maine. Freedom came by phone from the town clerk, Cindy Abbott (331 to 115, 24 blank); her written return or sample ballot would still confirm its ballot wording. North Berwick came by phone from the town office (2,114 to 582); the town says it posted the result on Facebook, which needs a login, so swap in its scanned return when one appears in its Document Center. Sprigg is the closest race on the page: For leads 330 to 297, 33 votes.
- **Marked final (15):** Hubbard, El Dorado, Conneaut, Pataskala, Granville, Wilmington parcels 1–4, Emporia, Americus and Edgewater, plus Piqua OH (added Nov 4 from Miami County's canvass: 4,061 to 2,027) and Morgan County IL (by phone from the clerk's office: 9,413 to 1,250, unofficial; Illinois has two weeks to make it official, so retype it then), and Belvidere NJ (added Nov 4 from Warren County's unofficial summary: 711 to 240; the county's site blocks scripts, so retype it when Warren certifies).

Hand-entered numbers stay pinned until you clear them. Ohio adds provisional and late mail ballots at its official canvass later in November; retype a race then if you want the certified count.

## Feeds behind the hand entries

The loop can now read the county's own source for four hand-entered races (Nov 4), each checked against the live site and matching the sheet:

| Race | Source | Reads |
|---|---|---|
| Sunbury | Delaware's NIST results feed (new `nist_json` reader) | 2,809 to 763, 6 of 6 precincts |
| El Dorado | Butler County KS's livevoterturnout page (`ohio_enr`) | 2,966 to 1,183, no precinct count |
| Hubbard | Trumbull's `pdfs/Election Summary.pdf`, a fixed file it overwrites | 2,622 to 802, no precinct count |
| Ottawa | The newest "2026-General" sheet linked from Franklin County KS's home page (the PDF reader's new `inline` option) | 2,882 to 1,129, no precinct count |

A sheet row with numbers wins, so the feeds take over only when you clear a row. Sunbury could be cleared any time: its feed reports every precinct, so it stays complete. The other three report no precincts and would show as partly counted, so keep their rows (and their finals) until the canvass, then clear them or retype the certified count.

## If something goes wrong

- **A race stops updating:** check the county page, then save its file to the drop folder or type the numbers into the sheet.
- **A count looks wrong:** type the county's numbers into the sheet. Your numbers win until you clear them.
- **Clarity errors (Illinois and Downe):** the loop keeps each race's last numbers and catches up when Clarity answers.
- **Direct county files misbehave:** stop the loop with Ctrl-C in its terminal, then restart it with `DCBT_DIRECT=0 Rscript R/watch.R 120`. It goes back to reading only the drop folder.
- **The loop stops, or you want it back:** restart it with `caffeinate -i Rscript R/watch.R 120` from the repo folder.
