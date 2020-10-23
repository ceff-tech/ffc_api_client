
library(ffcAPIClient)

token = Sys.getenv("EFLOWS_WEBSITE_TOKEN")

# disable some checks on the number of years of data and timeseries filtering
pkg.env$FILTER_TIMESERIES <- FALSE
pkg.env$FAIL_YEARS_DATA <- 1

assessed_observations_lt_50 = c(-1,-1,0,0,0,0,1,1,1,1,1,1)
assessed_observations_gt_50 <- c(1,0,0,1,-1,1,1,-1,0,0,0,0,0,0,0)
test_predictions = list("p10" = 5, "p25" = 7, "p50" = 10, "p75" = 13, "p90" = 15)

context("simple alteration status checks")

test_that("registers unaltered correctly", {
  basic_check <- determine_status(median = 8,
                                  predictions = test_predictions,
                                  assessed_observations = assessed_observations_gt_50,
                                  metric = "Metric_With_Tim",
                                  days_in_water_year = 365)
  expect_equal(LIKELY_UNALTERED_STATUS_CODE, 1)
  expect_equal(basic_check$status_code, LIKELY_UNALTERED_STATUS_CODE)
  expect_equal(basic_check$alteration_type, "none_found")
  expect_equal(basic_check$status, "likely_unaltered")

})

test_that("iqr edges are unaltered", {
  basic_check <- determine_status(median = 7,
                                  predictions = test_predictions,
                                  assessed_observations = assessed_observations_gt_50,
                                  metric = "Metric_With_Tim",
                                  days_in_water_year = 365)
  expect_equal(basic_check$status_code, LIKELY_UNALTERED_STATUS_CODE)
  expect_equal(basic_check$status, "likely_unaltered")
  expect_equal(basic_check$alteration_type, "none_found")

  basic_check <- determine_status(median = 13,
                                  predictions = test_predictions,
                                  assessed_observations = assessed_observations_gt_50,
                                  metric = "Metric_With_Tim",
                                  days_in_water_year = 365)
  expect_equal(basic_check$status_code, LIKELY_UNALTERED_STATUS_CODE)
  expect_equal(basic_check$status, "likely_unaltered")
  expect_equal(basic_check$alteration_type, "none_found")
})

test_that("i80r unaltered", {
  basic_check <- determine_status(median = 6,
                                  predictions = test_predictions,
                                  assessed_observations = assessed_observations_gt_50,
                                  metric = "Metric_Name",
                                  days_in_water_year = 365)
  expect_equal(basic_check$status_code, LIKELY_UNALTERED_STATUS_CODE)
  expect_equal(basic_check$status, "likely_unaltered")
  expect_equal(basic_check$alteration_type, "none_found")

  basic_check <- determine_status(median = 14,
                                  predictions = test_predictions,
                                  assessed_observations = assessed_observations_gt_50,
                                  metric = "Metric_Name",
                                  days_in_water_year = 365)
  expect_equal(basic_check$status_code, LIKELY_UNALTERED_STATUS_CODE)
  expect_equal(basic_check$status, "likely_unaltered")
  expect_equal(basic_check$alteration_type, "none_found")

  basic_check <- determine_status(median = 5,
                                  predictions = test_predictions,
                                  assessed_observations = assessed_observations_gt_50,
                                  metric = "Metric_Name",
                                  days_in_water_year = 365)
  expect_equal(basic_check$status_code, LIKELY_UNALTERED_STATUS_CODE)
  expect_equal(basic_check$status, "likely_unaltered")
  expect_equal(basic_check$alteration_type, "none_found")

  basic_check <- determine_status(median = 15,
                                  predictions = test_predictions,
                                  assessed_observations = assessed_observations_gt_50,
                                  metric = "Metric_Name",
                                  days_in_water_year = 365)
  expect_equal(basic_check$status_code, LIKELY_UNALTERED_STATUS_CODE)
  expect_equal(basic_check$status, "likely_unaltered")
  expect_equal(basic_check$alteration_type, "none_found")
})

test_that("indeterminate", {
  basic_check <- determine_status(median = 10,
                                  predictions = test_predictions,
                                  assessed_observations = assessed_observations_lt_50,
                                  metric = "Metric_Tim",
                                  days_in_water_year = 365)
  expect_equal(basic_check$status_code, INDETERMINATE_STATUS_CODE)
  expect_equal(basic_check$status, "indeterminate")
  expect_equal(basic_check$alteration_type, "unknown")  # median isn't off, but observations are in this case, so alteration_type won't change

  basic_check <- determine_status(median = 6,
                                  predictions = test_predictions,
                                  assessed_observations = assessed_observations_lt_50,
                                  metric = "Metric_Tim",
                                  days_in_water_year = 365)
  expect_equal(basic_check$status_code, INDETERMINATE_STATUS_CODE)
  expect_equal(basic_check$status, "indeterminate")
  expect_equal(basic_check$alteration_type, "early")


  basic_check <- determine_status(median = 14,
                                  predictions = test_predictions,
                                  assessed_observations = assessed_observations_lt_50,
                                  metric = "Metric_Tim",
                                  days_in_water_year = 365)
  expect_equal(basic_check$status_code, INDETERMINATE_STATUS_CODE)
  expect_equal(basic_check$status, "indeterminate")
  expect_equal(basic_check$alteration_type, "late")


  basic_check <- determine_status(median = 5,
                                  predictions = test_predictions,
                                  assessed_observations = assessed_observations_lt_50,
                                  metric = "Metric_Name",
                                  days_in_water_year = 365)
  expect_equal(basic_check$status_code, INDETERMINATE_STATUS_CODE)
  expect_equal(basic_check$status, "indeterminate")
  expect_equal(basic_check$alteration_type, "low")


  basic_check <- determine_status(median = 15,
                                  predictions = test_predictions,
                                  assessed_observations = assessed_observations_lt_50,
                                  metric = "Metric_Name",
                                  days_in_water_year = 365)
  expect_equal(basic_check$status_code, INDETERMINATE_STATUS_CODE)
  expect_equal(basic_check$status, "indeterminate")
  expect_equal(basic_check$alteration_type, "high")
})


test_that("likely_altered registers", {
  basic_check <- determine_status(median = 4,
                                  predictions = test_predictions,
                                  assessed_observations = assessed_observations_lt_50,
                                  metric = "Metric_Tim",
                                  days_in_water_year = 365)
  expect_equal(basic_check$status_code, LIKELY_ALTERED_STATUS_CODE)
  expect_equal(basic_check$alteration_type, "early")


  basic_check <- determine_status(median = 16,
                                  predictions = test_predictions,
                                  assessed_observations = assessed_observations_lt_50,
                                  metric = "Metric_Tim",
                                  days_in_water_year = 365)
  expect_equal(basic_check$status_code, LIKELY_ALTERED_STATUS_CODE)
  expect_equal(basic_check$alteration_type, "late")


  basic_check <- determine_status(median = 4,
                                  predictions = test_predictions,
                                  assessed_observations = assessed_observations_lt_50,
                                  metric = "Metric_Name",
                                  days_in_water_year = 365)
  expect_equal(basic_check$status_code, LIKELY_ALTERED_STATUS_CODE)
  expect_equal(basic_check$alteration_type, "low")


  basic_check <- determine_status(median = 16,
                                  predictions = test_predictions,
                                  assessed_observations = assessed_observations_lt_50,
                                  metric = "Metric_Name",
                                  days_in_water_year = 365)
  expect_equal(basic_check$status_code, LIKELY_ALTERED_STATUS_CODE)
  expect_equal(basic_check$alteration_type, "high")
})

context("Gage alteration checks")


## TODO: These tests shouldn't pull live data - they could then fail randomly - we want to pull the test data and
## provide it directly - likely means we'll use evaluate_alteration instead.
test_that("Jones Bar Gage has Correct Alteration Scores", {
  # COMID: 8060983 , gage ID: 11417500
  results <- evaluate_gage_alteration(11417500, token, comid = 8060983, plot_results = FALSE)

  expect_equal(results$alteration[results$alteration$metric == "DS_Dur_WS", ]$status_code, LIKELY_UNALTERED_STATUS_CODE)
  expect_equal(results$alteration[results$alteration$metric == "FA_Mag", ]$status_code, INDETERMINATE_STATUS_CODE)  # in Alyssa's excel calc, this was likely altered because of differing percentile calculations
  expect_equal(results$alteration[results$alteration$metric == "SP_Mag", ]$status_code, INDETERMINATE_STATUS_CODE)
  expect_equal(results$alteration[results$alteration$metric == "Wet_BFL_Mag_10", ]$status_code, LIKELY_ALTERED_STATUS_CODE)
  expect_equal(results$alteration[results$alteration$metric == "Wet_BFL_Mag_50", ]$status_code, LIKELY_ALTERED_STATUS_CODE)
  expect_equal(results$alteration[results$alteration$metric == "Wet_Tim", ]$status_code, LIKELY_UNALTERED_STATUS_CODE)

})


test_that("Michigan Bar Gage has Correct Alteration Scores", {
  # COMID: 8060983 , gage ID: 11417500
  results <- evaluate_gage_alteration(11335000, token, plot_results = FALSE, force_comid_lookup = TRUE)

  expect_equal(results$alteration[results$alteration$metric == "DS_Dur_WS", ]$status_code, LIKELY_UNALTERED_STATUS_CODE)
  expect_equal(results$alteration[results$alteration$metric == "DS_Mag_50", ]$status_code, LIKELY_UNALTERED_STATUS_CODE)
  expect_equal(results$alteration[results$alteration$metric == "DS_Tim", ]$status_code, LIKELY_UNALTERED_STATUS_CODE)
  expect_equal(results$alteration[results$alteration$metric == "FA_Mag", ]$status_code, LIKELY_UNALTERED_STATUS_CODE)
  expect_equal(results$alteration[results$alteration$metric == "FA_Tim", ]$status_code, LIKELY_UNALTERED_STATUS_CODE)
  expect_equal(results$alteration[results$alteration$metric == "SP_ROC", ]$status_code, LIKELY_UNALTERED_STATUS_CODE)
  expect_equal(results$alteration[results$alteration$metric == "SP_Tim", ]$status_code, LIKELY_UNALTERED_STATUS_CODE)
})

