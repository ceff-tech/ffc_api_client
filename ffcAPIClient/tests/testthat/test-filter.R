context("Data Preprocessing")
token = Sys.getenv("EFLOWS_WEBSITE_TOKEN")

all_gage_data <- ffcAPIClient::example_gagedata()
raw_gage_data <- all_gage_data[all_gage_data$gage == 1, ]  # comes out with 10 timeseries - 1 for each of 10 gages

test_that("Keeps 1 Day Gap",{
  timeseries <- raw_gage_data
  timeseries[25, ]$flow <- NA  # set a value to NA
  expected_nrows <- nrow(timeseries) - 1 # subtract 1 because there's a trailing day it should remove as well
  expect_equal(expected_nrows, nrow(filter_timeseries(timeseries, "date", "flow", date_format_string = "%m/%d/%Y")))

  # then we'll add it to a FFCProcessor object and run setup to make sure it actually gets called there
  ffc <- ffcAPIClient::FFCProcessor$new()
  ffcAPIClient::set_token(token)
  ffc$set_up(timeseries = timeseries, comid=11111111, token = token)
  expect_equal(expected_nrows, nrow(ffc$timeseries))
})


test_that("Discards 2 Day Gap",{
  timeseries <- raw_gage_data
  timeseries[25, ]$flow <- NA  # set a value to NA
  timeseries[26, ]$flow <- NA  # set a value to NA
  # subtract 365 from the actual value because it should be dropped
  expected_nrows <- nrow(timeseries) - 366  # 366 because 365 for the year and 1 for the trailing day
  actual_nrows <- nrow(filter_timeseries(timeseries, "date", "flow", date_format_string = "%m/%d/%Y"))
  expect_equal(expected_nrows, actual_nrows)

  # then we'll add it to a FFCProcessor object and run setup to make sure it actually gets called there
  ffc <- ffcAPIClient::FFCProcessor$new()
  ffc$set_up(timeseries = timeseries, comid=11111111, token = token)
  expect_equal(expected_nrows, nrow(ffc$timeseries))
})


test_that("Discards water year with more than 7 days of missing values",{
  timeseries <- raw_gage_data
  timeseries[25, ]$flow <- NA  # set a value to NA
  timeseries[35, ]$flow <- NA  # set a value to NA
  timeseries[45, ]$flow <- NA  # set a value to NA
  timeseries[55, ]$flow <- NA  # set a value to NA
  timeseries[66, ]$flow <- NA  # set a value to NA
  timeseries[74, ]$flow <- NA  # set a value to NA
  timeseries[91, ]$flow <- NA  # set a value to NA
  timeseries[103, ]$flow <- NA  # set a value to NA
  expected_nrows <- nrow(timeseries) - 366 # 366 because 365 for the dropping the year with the NAs and 1 for the trailing day
  expect_equal(expected_nrows, nrow(filter_timeseries(timeseries, "date", "flow", date_format_string = "%m/%d/%Y")))
})

test_that("Keeps water year with exactly 7 days of missing values",{
  timeseries <- raw_gage_data
  timeseries[35, ]$flow <- NA  # set a value to NA
  timeseries[45, ]$flow <- NA  # set a value to NA
  timeseries[55, ]$flow <- NA  # set a value to NA
  timeseries[66, ]$flow <- NA  # set a value to NA
  timeseries[74, ]$flow <- NA  # set a value to NA
  timeseries[91, ]$flow <- NA  # set a value to NA
  timeseries[103, ]$flow <- NA  # set a value to NA
  expected_nrows <- nrow(timeseries) - 1 # Should keep all years, but still discard the last day
  expect_equal(expected_nrows, nrow(filter_timeseries(timeseries, "date", "flow", date_format_string = "%m/%d/%Y")))
})


