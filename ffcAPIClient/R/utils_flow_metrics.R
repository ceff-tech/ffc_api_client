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
  return(flow_metrics[flow_metrics$COMID == com_id, ])
}


#' @export
get_comid_for_long_lat <- function(longitude, latitude){
  if(length(nhdR::nhd_plus_list(vpu=18)) < 20){  # checks if the NHDPlus Data has already been downloaded
    # if there aren't at least 20 items (which is what it returns as of 2019/12/19), then the download might
    # be incomplete and we should forcibly have nhdR correct itself.
    nhdR::nhd_plus_get(vpu = 18, force_dl = TRUE, force_unzip = TRUE)  # downloads and caches it for use
  }

  # This does all the spatial stuff for us automatically - basically does a spatial join at this gage's
  # latitude and longitude to find the stream segments within 100 meters. Then we'll pull the COMIDs
  spatial_qry <- nhdR::nhd_plus_query(longitude,
                                      latitude,
                                      dsn = c("NHDFlowline"),
                                      buffer_dist = units::as_units(100, "m"))

  return(spatial_qry$sp$NHDFlowline[1]$COMID)  # gets the first COMID returned
}
