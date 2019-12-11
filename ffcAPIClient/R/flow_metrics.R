#' Retrieves flow predicted flow metric values for a stream segment
#'
#' This function returns the 10th, 25th, 50th, 75th, and 90th percentile
#' values for each flow metric as predicted for the stream segment you
#' identify with the \code{com_id} input variable. It returns a data
#' frame where the metrics are rows with names in the \code{metric} field, and
#' percentiles are available as fields such as \code{pct_10}, \code{pct_25}, etc
#' for each percentile.
#'
#' The raw flow metric data for all segments is available as package data
#' named \code{flow_metrics} so if you wish to do more advanced filtering,
#' you can do it there. But if you just want to filter by COM_ID, this function
#' can handle that for you.
#'
#' @export
get_predicted_flow_metrics <- function(com_id){
  return(flow_metrics[flow_metrics$COMID == com_id, ])
}
