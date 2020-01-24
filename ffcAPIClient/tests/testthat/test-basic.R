context("Package Workflows")
token = Sys.getenv("EFLOWS_WEBSITE_TOKEN")

test_that("Evaluate Gage Alteration Fails",{
  # This really only tests a generic failure - I want it to make sure the eflows website fails to run without a token
  # but what we really need is a pipeline that gets *real* gage data successfully, then tests that it doesn't run
  # without a token and then does run with a token. Expand this test!!
  timeseries <- ffcAPIClient::example_gagedata()
  expect_error(ffcAPIClient::evaluate_alteration(timeseries_df = timeseries, token="", comid=1111111))
})

test_that("Evaluate Gage Alteration Runs",{
  ffcAPIClient::set_token(token)
  results <- ffcAPIClient::evaluate_gage_alteration(gage_id = 11336000, token = token)  # run for mcconnell gage on cosumnes
  expect_is(results, "list")
  results <- ffcAPIClient::evaluate_gage_alteration(gage_id = 103087889, token = token)  # run for 4L Creek, Markleeville, which has some funky results
  expect_is(results, "list")
})


