test_that("Gage COMID behaves", {
  gage_id <- 11336000
  gage <- ffcAPIClient::USGSGage$new()
  gage$id <- gage_id
  expect_error(gage$get_comid())  # right now, we use the gage's longitude and latitude to get IDs - need to get data befor we can use those though, so it should fail

  gage$get_data()
  gage$get_comid()
  expect_equal(gage$comid, 3953273)
})
