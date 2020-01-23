context("simple alteration checks")
library(ffcAPIClient)


assessed_observations_lt_50 = c(-1,-1,0,0,0,0,1,1,1,1,1,1)
assessed_observations_gt_50 <- c(1,0,0,1,-1,1,1,-1,0,0,0,0,0,0,0)
test_predictions = list("p10" = 5, "p25" = 7, "p50" = 10, "p75" = 13, "p90" = 15)

test_that("registers unaltered correctly", {
  basic_check <- determine_status(median = 8,
                                  predictions = test_predictions,
                                  assessed_observations = assessed_observations_lt_50,
                                  metric = "Metric_With_Tim",
                                  days_in_water_year = 365)
  expect_equal(LIKELY_UNALTERED_STATUS_CODE, 1)
  expect_equal(basic_check$status_code, LIKELY_UNALTERED_STATUS_CODE)
  expect_equal(basic_check$alteration_type, "none_found")
  expect_equal(basic_check$status, "likely_unaltered")

})

test_that("interquartile edges are unaltered", {
  basic_check <- determine_status(median = 7,
                                  predictions = test_predictions,
                                  assessed_observations = assessed_observations_lt_50,
                                  metric = "Metric_With_Tim",
                                  days_in_water_year = 365)
  expect_equal(basic_check$status_code, LIKELY_UNALTERED_STATUS_CODE)
  expect_equal(basic_check$status, "likely_unaltered")
  expect_equal(basic_check$alteration_type, "none_found")

  basic_check <- determine_status(median = 13,
                                  predictions = test_predictions,
                                  assessed_observations = assessed_observations_lt_50,
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

test_that("i80r indeterminate", {
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

