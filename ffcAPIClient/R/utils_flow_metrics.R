
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
get_predicted_flow_metrics <- function(comid, online, wyt, fill_na_p10){
  if(missing(online)){
    online <- TRUE
  }

  if(missing(wyt)){
    wyt <- "all"
  }

  if(missing(fill_na_p10)){
    fill_na_p10 <- FALSE
  }

  if(online){
    return(get_predicted_flow_metrics_online(comid, wyt = wyt, fill_na_p10 = fill_na_p10))
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

get_predicted_flow_metrics_online <- function(comid, wyt, fill_na_p10){
  if(missing(wyt)){
    wyt = "all"
  }

  metrics_full <- read.csv(paste("https://flow-api.codefornature.org/v2/ffm/?comids=", comid, sep=""), stringsAsFactors = FALSE)
  if(wyt != "any"){
    metrics_filtered <- metrics_full[metrics_full$wyt == wyt,]
    metrics_filtered <- metrics_filtered[!names(metrics_filtered) %in% c("wyt")]  # now drop the wyt column, but only when we are filtering!
    # edit to return only model or inferred but NOT observed
    deduplicated <- metrics_filtered[metrics_filtered$source %in% c("model","inferred"),]
    #deduplicated <- metrics_filtered[!duplicated(metrics_filtered[,c("ffm")]), ]  # deduplicate on unique comid/metric combo
  } else {
    metrics_filtered <- metrics_full
    deduplicated <- metrics_filtered[!duplicated(metrics_filtered[,c("ffm", "wyt")]), ]
  }
  deduplicated["result_type"] <- "predicted"  # add a field indicating this is a prediction for later when DFs are merged
  deduplicated <- deduplicated[!names(deduplicated) %in% c("gage_id", "observed_years", "alteration")]  # Drop extra columns from the API

  if(nrow(deduplicated) < nrow(metrics_filtered)){
    warning("Flow metric data from API contained duplicated records for some flow metrics that we automatically removed. This is a data quality issue in the predicted data - it can occasionally produce incorrect results - check the values of the predicted flow metrics at https://flows.codefornature.org")
  }

  deduplicated <- fill_na_10th_percentile(deduplicated, fill_na_p10)

  return(replace_ffm_column(deduplicated))  # rename the "ffm" column to "metric"

}


#' Fill 10th Percentile NA values when 25th percentile value is 0
#'
#' Sometimes data from the predicted metrics API has NA values in the 10th percentile field due to modeling errors where these numbers
#' were originally set to negative values and were replaced with NA in the API. This function, which needs to be enabled using
#' the ffc$predicted_percentiles_fill_na_p10 flag on FFCProcessor objects, fills any NA values it finds in the p10 field *if*
#' the p25 field is 0. Otherwise, it leaves them as they are. Raises a warning if it finds any NA values in the p10 field regardless
#' of whether it fills them.
#'
#' This function can be used with any other data frame that containes field p10 and p25 as well, though I'm not sure the conditions
#' you'd need to!
#'
#' @export
fill_na_10th_percentile <- function(df, fill_na_p10){
  if(any(is.na(df$p10))){  # if we have any NA values in the p10 field - sometimes these occur because of how the API processes the data
    if(fill_na_p10){
      df[is.na(df$p10) & df$p25 == 0,]$p10 <- 0  # fill only those where p10 is NA and p25 is 0
      warning("Predicted flow metrics have NA values in the 10th percentile column - they have been filled with 0 values where the 25h percentile value is 0 and left as is otherwise")
      if(any(is.na(df$p10))){  # if we still have NAs, then some weren't filled - warn the user
        warning("Unfilled NAs remain in the p10 column - we can't safely fill these because the p25 column is greater than 0 - this will likely break the code later in the package, so expect an error! These NA values should be addressed more broadly by the CEFF tech team.")
      }
    }else{
      warning("Predicted flow metrics have NA values in the 10th percentile column - this is a data quality issue in the predicted metrics API. You can enable ffc$predicted_percentiles_fill_na_p10 to automatically fill these values with the 25th percentile data. As is, they are likely to cause failures later in the analysis.")
    }
  }
  return(df)
}


#' Retrieves COMID for a given USGS gage which collects daily data.
#'
#' This function returns the COMID associated with a specific USGS gage.
#' It can be used to associate gage data with flow metric predictions a
#' stream segment identified with the \code{com_id} input variable.
#'
#' @param longitude numeric. Longitude or X.
#' @param latitude numeric. Longitude or Y.
#' @param online boolean. Default TRUE. When TRUE, looks up the COMID using the nhdplustools
#' package and USGS web services. Sometimes these are spotty though, so you can set offline
#' to FALSE and this function will perform the lookup locally with spatial data. It will still
#' download a large amount of spatial data for
#' NHD segments the first time it runs with the flag set to FALSE, but then future lookups will be
#' much faster. It uses the nhdR package, which is not included as a package requirement, and instead
#' is installed only if you set \code{ffc$get_comid_online = FALSE}.
#'
#' @export
get_comid_for_lon_lat <- function(longitude, latitude, online=TRUE){
  if(online){
    return(get_comid_for_lon_lat_online(longitude, latitude))
  }else{
    return(get_comid_for_lon_lat_offline(longitude, latitude))
  }
}

get_comid_for_lon_lat_online <- function(longitude, latitude){
  start_point <- sf::st_sfc(sf::st_point(c(longitude, latitude)), crs = 4269)
  return(nhdplusTools::discover_nhdplus_id(start_point))
}


get_comid_for_lon_lat_offline <- function(longitude, latitude){

  # not going to make this a normal required package because I'm not sure we'll use it in most cases
  if (!("nhdR" %in% installed.packages())){
    install.packages("nhdR",dep=TRUE)
    if(!("nhdR" %in% installed.packages())) stop("Couldn't install nhdR")
  }

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
