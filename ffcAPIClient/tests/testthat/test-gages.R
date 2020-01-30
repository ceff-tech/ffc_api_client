context("Gages")

library(ffcAPIClient)  # TODO: The test can't find USGSGage when run via "check" (but works fine via "test") unless
                        # I include this (won't work with just the package prefix). I'd like to resolve this, but for now,
                        # this makes the test pass, and tests that use the gage code itself pass, so I'm not super worried about it.

test_that("Gage COMID behaves", {
  gage_id <- 11336000
  gage <- USGSGage$new()
  gage$id <- gage_id

  expect_error(gage$get_comid())  # right now, we use the gage's longitude and latitude to get IDs - need to get data befor we can use those though, so it should fail

  gage$get_data()
  gage$get_comid()
  expect_equal(gage$comid, 3953273)
})

test_that("Gage COMID Override behaves", {
  gage_id <- 11417500  # this gage is Jones Bar - the normal lookup gives the wrong COMID, but we have an override list for it
  gage <- USGSGage$new()
  gage$id <- gage_id

  gage$get_data()
  gage$get_comid()
  expect_equal(gage$comid, 8060893)
})
