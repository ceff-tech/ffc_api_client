token = Sys.getenv("EFLOWS_WEBSITE_TOKEN")
ffcAPIClient::set_token(token)

test_that("Evaluate Gage Alteration Runs",{
  results <- ffcAPIClient::evaluate_gage_alteration(gage_id = 11336000, token = token)  # run for mcconnell gage on cosumnes
  expect_is(results, "vector")
})
