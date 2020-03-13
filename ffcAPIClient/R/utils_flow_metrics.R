
# create an environment to store data that we load only when we need it, but where the data is also public
ffcAPIClient_data_env <- new.env()

# this function lets us have one environment where we load the data from disk a single time.
# on the first load, it checks if the data is already in the environment, and then on subsequent
# calls for the same dataset, just returns that dataset.
get_dataset <- function(dataset_name){
  if(!hasName(ffcAPIClient_data_env, dataset_name)){  # if it's not already loaded into our data environment, load it
    data(list=c(dataset_name), envir=ffcAPIClient_data_env, package="ffcAPIClient")  # need it to be in a list or else it treats it as a bareword dataset (but still works???)
  }
  # then return it for use
  return(get(dataset_name, envir=ffcAPIClient_data_env))

}

#' Retrieves flow predicted flow metric values for a stream segment
#'
#' This function returns the 10th, 25th, 50th, 75th, and 90th percentile
#' values for each flow metric as predicted for the stream segment you
#' identify with the \code{comid} input variable. It returns a data
#' frame where the metrics are rows with names in the \code{metric} field, and
#' percentiles are available as fields such as \code{pct_10}, \code{pct_25}, etc
#' for each percentile.
#'
#'
#' @param comid character. A string of a NHD COMID to retrieve metrics for.
#' @param online boolean. Default FALSE. When TRUE, retrieves data from TNC's experimental predicted flow metrics API.
#'        When FALSE, uses internal data to pull flow metrics. Both are reasonably fast, but offline is good for reliability,
#'        but may end up using older data. Online should pull the most current data if there are updates. FALSE is the default
#'        largely because the API is still unstable.
#' @param wyt character. When online = TRUE, filters the result to records with only the specifc water year type indicated.
#'        See TNC's flow API documentation at flow-api.codefornature.org for options. If you want the records to come back
#'        unfiltered, use "any", and for the non-WYT records, use "all" (it's a specific keyword the data uses - not our
#'        choice - sorry for any confusion!).
#'
#' @export
get_predicted_flow_metrics <- function(comid, online, wyt){
  if(missing(online)){
    online <- TRUE
  }

  if(missing(wyt)){
    wyt <- "all"
  }

  if(online){
    return(get_predicted_flow_metrics_online(comid, wyt = wyt))
  } else {
    return(get_predicted_flow_metrics_offline(comid))
  }
}

get_predicted_flow_metrics_offline <- function(comid){
  flow_metrics <- get_dataset("flow_metrics")
  flow_metrics["result_type"] <- "predicted"
  flow_metrics$metric <- as.character(flow_metrics$metric)
  return(flow_metrics[flow_metrics$comid == comid, ])
}

get_predicted_flow_metrics_online <- function(comid, wyt){
  if(missing(wyt)){
    wyt = "all"
  }

  metrics_full <- read.csv(paste("https://flow-api.codefornature.org/v2/ffm/?comids=", comid, sep=""), stringsAsFactors = FALSE)
  if(wyt != "any"){
    metrics_filtered <- metrics_full[metrics_full$wyt == wyt,]
    metrics_filtered <- metrics_filtered[!names(metrics_filtered) %in% c("wyt")]  # now drop the wyt column, but only when we are filtering!
    deduplicated <- metrics_filtered[!duplicated(metrics_filtered[,c("ffm")]), ]  # deduplicate on unique comid/metric combo
  } else {
    metrics_filtered <- metrics_full
    deduplicated <- metrics_filtered[!duplicated(metrics_filtered[,c("ffm", "wyt")]), ]
  }
  deduplicated["result_type"] <- "predicted"

  if(nrow(deduplicated) < nrow(metrics_filtered)){
    warning("Flow metric data from API contained duplicated records for some flow metrics that we automatically removed. This is a data quality issue in the predicted data - it can occasionally produce incorrect results - check the values of the predicted flow metrics at https://flows.codefornature.org")
  }

  return(replace_ffm_column(deduplicated))  # rename the "ffm" column to "metric"

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

replace_ffm_column <- function(df){

  ffms = as.data.frame(t(data.frame(
    list(
      "ds_mag_50" = "DS_Mag_50",
      "ds_mag_90" = "DS_Mag_90",
      "ds_dur_ws" = "DS_Dur_WS",
      "ds_tim" = "DS_Tim",
      "fa_tim" = "FA_Tim",
      "fa_dur" = "FA_Dur",
      "fa_mag" = "FA_Mag",
      "peak_10" = "Peak_10",
      "peak_2" = "Peak_2",
      "peak_5" = "Peak_5",
      "peak_dur_10" = "Peak_Dur_10",
      "peak_dur_2" = "Peak_Dur_2",
      "peak_dur_5" = "Peak_Dur_5",
      "peak_fre_10" = "Peak_Fre_10",
      "peak_fre_2" = "Peak_Fre_2",
      "peak_fre_5" = "Peak_Fre_5",
      "sp_dur" = "SP_Dur",
      "sp_mag" = "SP_Mag",
      "sp_tim" = "SP_Tim",
      "sp_roc" = "SP_ROC",
      "wet_bfl_dur" = "Wet_BFL_Dur",
      "wet_bfl_mag_10" = "Wet_BFL_Mag_10",
      "wet_bfl_mag_50" = "Wet_BFL_Mag_50",
      "wet_tim" = "Wet_Tim"
    ),
    stringsAsFactors = FALSE
  )), stringsAsFactors = FALSE)

  ffms$ffm <- rownames(ffms)
  colnames(ffms) <- c("metric", "ffm")

  metrics <- merge(df, ffms)  # attach the new metric column - this turns my character columns into a factor, annoyingly.
  metrics$metric <- as.character(metrics$metric)
  return(metrics[!names(metrics) %in% c("ffm", "unit")])  # now drop the ffm column
}
