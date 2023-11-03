source("renv/activate.R")

if (Sys.info()["sysname"] == "Linux") {
  options(repos =
            getOption("repos") |>
            magrittr::inset("CRAN", "https://packagemanager.rstudio.com/cran/latest") |>
            renv:::renv_rspm_transform())
}
