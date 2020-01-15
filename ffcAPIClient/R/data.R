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


#' Geomorphic Stream Classification
#'
#' Contains the geomorphic classification by stream COMID for ~70,000 stream
#' segments in California (low-order streams excluded). Streams were classified
#' as described in Lane, Belize A., Samuel Sandoval-Solis, Eric D. Stein,
#' Sarah M. Yarnell, Gregory B. Pasternack, and Helen E. Dahlke. 2018.
#' “Beyond Metrics? The Role of Hydrologic Baseline Archetypes in Environmental
#'  Water Management.” Environmental Management 62 (4): 678–93.
#'  https://doi.org/10.1007/s00267-018-1077-7.
#'
#'@format A data frame :
#' \describe{
#'   \item{CLASS}{The stream classification ID}
#'   \item{COMID}{The NHD COMID of the stream segment}
#'   \item{CLASS_CODE}{The character stream classification ID - follows the form:
#'     SM = Snowmelt, HSR = High Volume Snowmelt and Rain, LSR = Low Volume Snowmelt and Rain,
#'     WS = Winter Storms, GW = Groundwater, PGR = Perennial Groundwater and Rain,
#'     FER = Flashy Ephemeral Rain, RGW = Rain and Seasonal Groundwater,
#'     HLP = High elevation, low precipitation
#'   }
#' }
#' \url{https://doi.org/10.1007/s00267-018-1077-7}

#'
"stream_class_data"
