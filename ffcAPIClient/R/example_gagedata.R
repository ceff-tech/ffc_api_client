
#' @export
example_gagedata <- function(startdate = "2009/10/01", stopdate = "2019/10/01", mean = 100, sd = 50, gages = 1:10) {
  # Written beginning October 30, 2019 by Daniel Philippus for the LA River Environmental Flows project
  # at the Colorado School of Mines.
  result <- data.frame()
  dates <- format(as.Date(as.Date(startdate):as.Date(stopdate), origin = "1970/01/01"), format = "%m/%d/%Y")
  nflows <- length(dates)
  for (gage in gages) {
    gn = as.character(gage)
    gmean <- rnorm(1, mean, sd)
    gmean <- if (gmean > 0) gmean else 0
    df <- data.frame(gage = gn, date = dates)
    flows <- rnorm(nflows, gmean, sd)
    flows <- vapply(flows, function(x) {if (x > 0) x else 0 }, 1)
    df$flow <- flows
    result <- rbind(result, df)
  }
  result$gage <- as.character(result$gage)
  result
}
