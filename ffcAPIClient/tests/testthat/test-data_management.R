context("Data loading and management functions")
library(ffcAPIClient)

test_that("Shouldn't exist before we load it", {
  expect_false(exists("something", envir = ffcAPIClient_data_env))
  expect_false(exists("stream_class_data", envir = ffcAPIClient_data_env, inherits = FALSE))
})

test_that("Succeeds at basic loading", {
  get_dataset("stream_class_data")
  expect_true(exists("stream_class_data", envir = ffcAPIClient_data_env))
  expect_equal(get_stream_class_code_for_comid(17636786), "LSR")
  expect_equal(length(get_stream_class_code_for_comid(9838328932893289523)), 0)  # confirm we get an item of length 0 back if we put in something gibberishy
})
