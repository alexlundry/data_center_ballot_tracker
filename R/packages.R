# Packages used by the pipeline. Install once with:
#   install.packages(c("tidyverse", "httr2", "jsonlite", "rvest", "xml2",
#                      "readxl", "glue", "cli", "pdftools"))
# pdftools is only needed for the pdf adapter; it is loaded lazily there.
suppressPackageStartupMessages({
  library(tidyverse)
  library(httr2)
  library(jsonlite)
  library(rvest)
  library(xml2)
  library(readxl)
  library(glue)
  library(cli)
})
