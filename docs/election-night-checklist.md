# After the election: what still needs you (updated Nov 10, 2026)

Updated 9:30 am ET Nov 10, a week after the election. Of the 47 measures, **29 are final, 16 are complete with every precinct in but await their county's official canvass, and 2 are still counting** (Boulder City NV and Alhambra CA). Nothing needs a call. What's left, in date order:

1. **Nov 13: mark Boulder City final** once its City Council canvasses the returns (section 1).
2. **Through Nov 24: enter official counts as counties certify** (section 2). Ohio, Illinois, North Dakota and Wisconsin are still canvassing; Adams County OH was first, on Nov 9, and its canvass moved Sprigg from 330 to 297 to 332 to 301.
3. **Nov 27: mark Alhambra final** when Los Angeles County certifies (section 1).

## How to enter a race in the sheet

Use the `manual_results` tab of the [Google Sheet](https://docs.google.com/spreadsheets/d/1jma2RqwyFNB8dP23f0nM4LCRti54uBJBoqEIktR9fRs/edit), on the race's row:

- Type `yes_votes` and `no_votes` exactly as the county or town labels them. Never flip them; the dashboard works out restrict and allow.
- Fill `as_of`, `source_url` and `entered_by`, plus the precincts if given. A one-precinct town entered as 1 of 1 shows as complete.
- `override` is already TRUE on every row, so your numbers replace the feed on the next pass (about two minutes). To hand a race back to the feed, clear its numbers and status.
- Set `status = final` once the count is complete. A status takes effect only on a row with YES and NO numbers, so to mark an automatic race final, type its current numbers into its row too; it then stays pinned there and the feed no longer updates it.
- To tell readers when a count is coming, type one sentence in `public_note` (column Z).

## 1. Still counting

| Race | Now | When it's done |
|---|---|---|
| Boulder City NV | NO leads 5,216 to 2,161 (NO = restrict, 70.7%): Clark County's count posted 6:46 pm Nov 9, after the 5 pm signature-cure deadline | Mail ballots had to arrive by Nov 7. The City Council canvasses the returns and declares the result on Nov 13 (recount demands close Nov 18). Type the canvassed count into its row with `status = final` then |
| Alhambra CA | 18,886 to 3,620 (Restrict 83.9%), after LA County's Nov 9 update | LA County updates daily through Nov 13, then on Nov 17, 19, 25 and 27, and is scheduled to certify on Nov 27 (its countywide estimate on Nov 8 was 53,000 ballots left). The feed keeps it current; mark it final at certification |

Both rows' `public_note` now tells readers these dates; update it if a date moves.

GitHub's results job is scheduled hourly through Nov 13 but has run only every few hours. For a sheet edit you want on the page right away, do one pass on the Mac: `git pull --rebase`, `Rscript R/fetch_results.R`, then commit and push `site/data/results.json`, `site/data/results.csv` and `data/history.csv` with the message `results <UTC time>` (this is what the loop did each pass). `gh workflow run update-results.yml` also works, but GitHub can't read Clarity, so it marks the six Illinois township feeds as failed until the next Mac pass (the page hides that for complete counts). By Nov 10, boe.ohio.gov had put its county result files back behind its bot check, so even the Mac can't read Urbana, Defiance or Trenton; their Nov 3 counts stay on the page. The desktop app's browser still opens the county pages, but its PDF links download instead of opening.

## 2. Official canvasses: where each certified count will come from

| Races | Status on the page | Canvass |
|---|---|---|
| Urbana (Champaign), Defiance, Trenton (Butler), Upper Sandusky (Wyandot), Monroeville (Huron), Sunbury (Delaware), Ashville (Pickaway), Perry Village (Lake) | Complete, unofficial | Ohio boards canvass Nov 8 to 24 and add provisionals and late mail ballots then. On Nov 10, Champaign's, Defiance's and Wyandot's files were unchanged since election night. Adams replaced its `/adams/c/elecres/20261103results.pdf` with the certified report (headed "Official Canvass", with the board's signed certification form on page 1); watch the same address in the other counties |
| Grove City, Oregon, Hubbard, Conneaut, Pataskala, Granville, Wilmington parcels 1–4, Piqua | Final on the unofficial count | Same Ohio canvass; retype each certified count. Clinton's and Licking's re-posted files (Nov 5 and Nov 4) still held the election-night counts on Nov 10, with zero provisionals |
| Bloomington, Joliet Township, the Chouteau, Granite City, Nameoki and Venice townships | Complete, unofficial (Clarity feed) | Illinois counts mail ballots postmarked by Nov 3 through Nov 17 and canvasses by Nov 24. Clarity was unchanged on Nov 10. A Mac pass picks up a new count if the county posts it to the same page |
| Morgan County IL | Final on the unofficial count (by phone) | Same Illinois canvass; retype the certified count |
| Harwood ND | Complete, unofficial (state feed) | Cass County's canvassing board meets on the 13th day, about Nov 16, and counts absentee ballots that arrive before then; the state feed updates on its own |
| Janesville WI | Complete, unofficial | Rock County's page still read "Unofficial Results" (10:56 pm Nov 3) on Nov 10 |
| El Dorado, Emporia, Americus, Ottawa KS; Downe and Belvidere NJ; Edgewater FL | Final on the unofficial count | Retype when each county certifies (Warren County NJ's site blocks scripts; open it in a browser) |

## Done: 29 final

- **Final on certified counts (2):** Sprigg Township (For 332, Against 301, so For won by 31; election night had 330 to 297) and Monroe Township (149 to 102; election night had 148 to 100), from Adams County's Official Canvass, certified by its board on Nov 9. The scan has no text; Claude read it page by page in the desktop app's browser.
- **Final, every ballot counted (8, Maine):** North Berwick (the clerk's certified return), Peru, Wells, Wiscasset, Brownfield, Eliot, Freedom and Sabattus. Maine towns count every ballot on election night (absentee ballots had to reach the clerk by 8 pm Nov 3), so seven were marked final on Nov 10. Wiscasset still links the Boothbay Register story: the town had posted no results by Nov 10, and its clerk's office confirmed the same 1,363 to 712 by phone on Nov 5. Freedom came by phone from the town clerk, Cindy Abbott (331 to 115, 24 blank); her written return or sample ballot would still confirm its ballot wording.
- **Final on the election-night count (19):** Grove City, Oregon, Hubbard, Conneaut, Pataskala, Granville, Wilmington parcels 1–4 and Piqua in Ohio; El Dorado, Emporia, Americus and Ottawa in Kansas; Downe Township and Belvidere in New Jersey; Edgewater FL; and Morgan County IL. Ottawa and Downe were confirmed final by phone with their county clerks on Nov 5 (Downe's Clarity page still shows 0% of districts reporting, so its row stays pinned). Section 2 says where each certified count will come from.

Hand-entered numbers stay pinned until you clear them.

## Feeds behind the hand entries

The loop can now read the county's own source for four hand-entered races (Nov 4), each checked against the live site and matching the sheet:

| Race | Source | Reads |
|---|---|---|
| Sunbury | Delaware's NIST results feed (new `nist_json` reader) | 2,809 to 763, 6 of 6 precincts |
| El Dorado | Butler County KS's livevoterturnout page (`ohio_enr`) | 2,972 to 1,183, no precinct count (6 more Yes at 1:39 pm CST Nov 4; the sheet now has the new count) |
| Hubbard | Trumbull's `pdfs/Election Summary.pdf`, a fixed file it overwrites | 2,622 to 802, no precinct count |
| Ottawa | The newest "2026-General" sheet linked from Franklin County KS's home page (the PDF reader's new `inline` option) | 2,882 to 1,129, no precinct count |

A sheet row with numbers wins, so the feeds take over only when you clear a row. Sunbury could be cleared any time: its feed reports every precinct, so it stays complete. The other three report no precincts and would show as partly counted, so keep their rows (and their finals) until the canvass, then clear them or retype the certified count.

## If something goes wrong

- **A race stops updating:** check the county page, then save its file to the drop folder or type the numbers into the sheet.
- **A count looks wrong:** type the county's numbers into the sheet. Your numbers win until you clear them.
- **Clarity errors (Illinois and Downe):** the loop keeps each race's last numbers and catches up when Clarity answers.
- **Direct county files misbehave:** stop the loop with Ctrl-C in its terminal, then restart it with `DCBT_DIRECT=0 Rscript R/watch.R 120`. It goes back to reading only the drop folder.
- **The loop stops, or you want it back:** restart it with `caffeinate -i Rscript R/watch.R 120` from the repo folder.
