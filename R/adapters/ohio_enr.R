# ---------------------------------------------------------------------------
# Adapter: Ohio county ENR pages (liveresults.boe.ohio.gov/ENR/<county>ohenr/
# and Franklin's liveresults.franklincountyohio.gov)
# ---------------------------------------------------------------------------
# sources.csv:  adapter = ohio_enr
#               results_url = .../<id>/en/Index_<id>.html (blocked host: the
#                             page comes through the drop folder, saved with
#                             "Webpage, Complete")
#               contest_pattern = regex for the contest title
#
# Every countywide contest has a heading link (aria-controls="raceContentId_N",
# aria-label "Contest: <title>"), a screen-reader heading raceHeading_N that may
# end "Precincts Reported: 57 of 57", and one row per choice whose cells carry
# data-race="N" (label in td[data-candidate], votes in td[data-votes]).
# Lucas's page also repeats every contest per precinct ("HARDING 1 - 8. Zoo
# Tax Levy") with different ids and attributes; those never match.
#
# All lookups are whole-document queries joined on N: querying inside each
# contest node one at a time takes about a minute on Lucas's 36 MB page.
# Checked against Butler (May 2026, id 23) and Lucas (May 2026, id 22).

adapter_ohio_enr <- function(src) {
  doc <- xml2::read_html(src$local_file %||% fetch_text(src$results_url))
  links <- xml2::xml_find_all(doc, "//a[starts-with(@aria-controls, 'raceContentId_')]")
  if (length(links) == 0) stop("no ENR contests (raceContentId_ links) on the page")
  contests <- tibble(
    race = str_remove(xml2::xml_attr(links, "aria-controls"), "^raceContentId_"),
    contest = str_squish(str_remove(xml2::xml_attr(links, "aria-label"), "^Contest:\\s*"))
  )
  heads <- xml2::xml_find_all(doc, "//span[starts-with(@id, 'raceHeading_')]")
  precincts <- tibble(race = str_remove(xml2::xml_attr(heads, "id"), "^raceHeading_"), text = xml2::xml_text(heads)) |>
    mutate(p = purrr::map(text, extract_precincts),
           precincts_reporting = purrr::map_int(p, 1), precincts_total = purrr::map_int(p, 2)) |>
    select(race, precincts_reporting, precincts_total)

  cand <- xml2::xml_find_all(doc, "//td[@data-candidate and @data-race]")
  votes <- xml2::xml_find_all(doc, "//td[@data-votes and @data-race]")
  choices <- tibble(
    race = xml2::xml_attr(cand, "data-race"), contestant = xml2::xml_attr(cand, "data-contestant"),
    # the label is printed twice (visible and screen-reader); take the visible one
    choice = str_squish(xml2::xml_text(xml2::xml_find_first(cand, "./span[@aria-hidden]")))
  ) |>
    left_join(tibble(race = xml2::xml_attr(votes, "data-race"), contestant = xml2::xml_attr(votes, "data-contestant"),
                     votes = parse_int(xml2::xml_text(votes))), by = c("race", "contestant"))

  tbl <- contests |>
    inner_join(choices, by = "race") |>
    left_join(precincts, by = "race") |>
    transmute(contest, choice, votes, precincts_reporting, precincts_total,
              ballots_cast = NA_integer_, registered_voters = NA_integer_)
  standardize_result(tbl, src)
}
