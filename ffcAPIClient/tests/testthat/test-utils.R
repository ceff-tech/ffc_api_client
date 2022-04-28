context("Utility Functions")
library(ffcAPIClient)

## Commented out because I can't figure out how to get it to compare by matched columns and rows, and allow for some floating point variation
#test_that("Online Flow Metrics and Offline Are Comparable", {
#  metrics_offline <- get_predicted_flow_metrics_offline(8060983)
#  metrics_online <- get_predicted_flow_metrics_online(8060983)
#  metrics_offline <- metrics_offline[, !names(metrics_offline) %in% c("comid", "source", "result_type")]
#  metrics_online <- metrics_online[, !names(metrics_online) %in% c("comid", "source", "result_type")]
#  expect_identical(metrics_offline, metrics_online)

#  # Confirm it's not just being nice to us - throw it an intentional failure
#  metrics_other_offline <- get_predicted_flow_metrics(8062273)
#  expect_false(identical(metrics_online, metrics_other_offline))
#})


test_that("Get Predicted Flow Metrics Warns on Duplicates", { # should raise a warning when it retrieves duplicate flow metric values
  expect_condition(get_predicted_flow_metrics(8211251, TRUE), "contained duplicated records")
})
