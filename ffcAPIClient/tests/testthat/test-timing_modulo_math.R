context("Timing Modulo Math")
library(ffcAPIClient)

test_that("Simple Midpoint Creation Works", {
  expect_equal(modulo_midpoint(350, 15, 365), 1)
})

test_that("Decimal Midpoint Works",{
  expect_equal(modulo_midpoint(330, 50.5, 365), (330 + (85.5 %/% 2)) %% 365)
})

test_that("Non-modulo Midpoint Works",{
  expect_equal(modulo_midpoint(300, 365, 365), 32)
})


# THESE TESTS SUPPLY value, early_value, late_value, days_in_water_year
# the "Rollover" tests mean that the value is on the opposite end of the water
# year from the value it's being assigned to "early" or "late", but we want to
# confirm it's being correctly assigned otherwise

test_that("Timing value is in range", {
  expect_equal(early_or_late(200, 100, 300, days_in_water_year = 365), "within range")
})


test_that("Late Midpoint Early Timing", {
  expect_equal(early_or_late(50, 100, 200, days_in_water_year = 365), "early")
})

test_that("Late Midpoint Early Timing Rollover", {
  expect_equal(early_or_late(350, 100, 200, days_in_water_year = 365), "early")
})


test_that("Late Midpoint Late Timing", {
  expect_equal(early_or_late(300, 100, 200, days_in_water_year = 365), "late")
})

# No possibility for Late Midpoint, Late Timing Rollover


test_that("Early Midpoint Early Timing", {
  expect_equal(early_or_late(65, 100, 350, days_in_water_year = 365), "early")
})

# No possibility for early midpoint, early timing rollover


test_that("Early Midpoint Late Timing", {
  expect_equal(early_or_late(50, 150, 325, days_in_water_year = 365), "late")
})

test_that("Early Midpoint Late Timing Rollover", {
  expect_equal(early_or_late(25, 150, 325, days_in_water_year = 365), "late")
})
