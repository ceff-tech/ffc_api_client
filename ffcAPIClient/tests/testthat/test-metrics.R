context("Flow Metric functions")
token = Sys.getenv("EFLOWS_WEBSITE_TOKEN")

# disable some checks on the number of years of data and timeseries filtering
pkg.env$FILTER_TIMESERIES <- FALSE
pkg.env$FAIL_YEARS_DATA <- 1

test_that("Metric Renaming is Handled Correctly",{
  ffcAPIClient::set_token(token)
  processor <- ffcAPIClient::evaluate_gage_alteration(gage_id = 11336000, token = token, force_comid_lookup = TRUE, return_processor=TRUE)  # run for mcconnell gage on cosumnes
  expect_true("Peak_2" %in% names(processor$ffc_results))
  expect_false("Peak_Mag_5" %in% names(processor$ffc_results))

  force_consistent_naming(TRUE)
  processor$run()
  expect_false("Peak_2" %in% names(processor$ffc_results))
  expect_true("Peak_Mag_5" %in% names(processor$ffc_results))
})

