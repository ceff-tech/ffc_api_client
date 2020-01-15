#' Modeled flow metric predictions for all stream segments
#'
#'
#' Contains the 10th, 25th, 50th, 75th, and 90th percentile
#' values for each flow metric and stream segment combination. It is a data
#' frame where the metrics are rows with names in the \code{Metric} field,
#' stream segment ID is in the COMID field and
#' percentiles are available as fields such as \code{pct_10}, \code{pct_25}, etc
#' for each percentile.
#'
#' @format A data frame :
#' \describe{
#'   \item{name}{text}
#'   \item{name}{text}
#'   ...
#' }
#' \url{https://github.com/ceff-tech/}
"flow_metrics"
