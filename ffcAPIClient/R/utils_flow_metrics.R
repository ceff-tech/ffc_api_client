#' Retrieves flow predicted flow metric values for a stream segment
#'
#' This function returns the 10th, 25th, 50th, 75th, and 90th percentile
#' values for each flow metric as predicted for the stream segment you
#' identify with the \code{com_id} input variable. It returns a data
#' frame where the metrics are rows with names in the \code{metric} field, and
#' percentiles are available as fields such as \code{pct_10}, \code{pct_25}, etc
#' for each percentile.
#'
#'
#' @param com_id character. A string of a NHD COMID to retrieve metrics for.
#'
#' @export
get_predicted_flow_metrics <- function(com_id){
  fm_data_env <- new.env()
  data("flow_metrics", envir=fm_data_env, package="ffcAPIClient")
  flow_metrics <- get("flow_metrics", envir=fm_data_env)
  return(flow_metrics[flow_metrics$COMID == com_id, ])
}

#' Retrieves COMID for a given USGS gage which collects daily data.
#'
#' This function returns the COMID associated with a specific USGS gage.
#' It can be used to associate gage data with flow metric predictions a
#' stream segment identified with the \code{com_id} input variable.
#'
#' @param gage_id character. A character formatted 8 digit USGS Gage ID.
#'
#' @export
get_comid_for_usgs_gage <- function(gage_id){
  if(!gage_id %in% ca_usgs_gages$site_id) {
    stop("no matching USGS gage with daily data, try again")}
  else {
    selected_gage <- dplyr::filter(ca_usgs_gages, site_id==gage_id)
    gage_comid <- nhdplusTools::discover_nhdplus_id(point = selected_gage)
    return(gage_comid)
  }
}

#' Retrieves COMID for a given USGS gage which collects daily data.
#'
#' This function returns the COMID associated with a specific USGS gage.
#' It can be used to associate gage data with flow metric predictions a
#' stream segment identified with the \code{com_id} input variable.
#'
#' @param longitude numeric. Longitude or X.
#' @param latitude numeric. Longitude or Y.
#'
#' @export
get_comid_for_lon_lat <- function(longitude, latitude){
  start_point <- sf::st_sfc(sf::st_point(c(longitude, latitude)), crs = 4269)
  return(nhdplusTools::discover_nhdplus_id(start_point))
}
