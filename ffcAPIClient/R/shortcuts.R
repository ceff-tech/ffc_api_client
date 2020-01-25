
#' Generate FFC Results and Plots for Gage Data
#'
#' This is a shortcut function that does most of the heavy lifting for you. Runs data through the FFC and transforms all results.
#'
#' If you provide it a USGS gage ID and your token to access the online functional flows calculator, this function then:
#'
#' 1. Download the timeseries data for the USGS gage
#'
#' 2. Look up the predicted unimpaired metric values for the gage's stream segment
#'
#' 3. Send the timeseries data through the functional flows calculator
#'
#' 4. Transform the results into a data frame with rows for years and metric values as columns
#'
#' 5. Produce percentiles for those metric values using R's recommended quantile method type 8 (which may return differing results from other methods, Excel, etc)
#'
#' 6. Transform the dimensionless reference hydrograph data into a data frame
#'
#' 7. Output plots comparing the observed timeseries data with the predicted unimpaired metric values.
#'
#' Items 4, 5, and 6 are returned back to the caller as a list with keys "ffc_results", "percentiles", and "drh_data" for
#' any further processing.
#'
#' @param gage_id The USGS gage ID to pull timeseries data from
#' @param token The token used to access the online FFC - see the Github repository's README under Setup for how to get this.
#' @param plot_output_folder Optional - when not provided, plots are displayed interactively only. When provided, they are
#'        displayed interactively and saved as files named by the functional flow componenent into the provided folder
#'
#' @export
evaluate_gage_alteration<- function (gage_id, token, plot_output_folder, plot_results){
  if(missing(plot_output_folder)){
    plot_output_folder <- NULL
  }

  if(missing(plot_results)){
    plot_results <- TRUE
  }

  set_token(token)
  gage <- USGSGage$new()
  gage$id <- gage_id
  gage$get_data()
  predictions_df <- gage$get_predicted_metrics()

  results_list <- evaluate_timeseries_alteration(gage$timeseries_data, gage$comid, predictions_df, plot_output_folder = plot_output_folder, plot_results = plot_results)
  return(results_list)
}


#' Generate FFC Results and Plots for Timeseries Data
#'
#' @export
evaluate_alteration <- function(timeseries_df, token, comid, longitude, latitude, plot_output_folder, date_format_string){
  if(missing(plot_output_folder)){
    plot_output_folder <- NULL
  }

  if(missing(comid) && (missing(longitude) || missing(latitude))){
    stop("Must provide either segment comid or *both* longitude and latitude to evaluate alteration. One of these
         is needed in order to look up predicted metrics for this location")
  }

  if(missing(comid)){  # now, if comid is null, we definitely have both latitude and longitude, so just get the COMID
    comid <- get_comid_for_lon_lat(longitude, latitude)
  }  # and if comid isn't null, then we already have it to proceed

  if(missing(date_format_string)){
    print("Using default date format string of %m/%d/%Y")
    date_format_string <- "%m/%d/%Y"
  }

  set_token(token)
  predicted_flow_metrics <- get_predicted_flow_metrics(comid)
  results_list <- evaluate_timeseries_alteration(timeseries_df, comid, predicted_flow_metrics, plot_output_folder, date_format_string)
  return(results_list)
}

#' Run Gage Data Through the Functional Flows Calculator
#'
#' Provided with an integer Gage ID, this function pulls the timeseries data for the
#' gage and processes it in a single step. Returns the functional flow calculator's results list.
#'
#' @param gage_id integer. The USGS Gage ID value for the gage you want to return timeseries data for
#'
#' @return list. Functional Flow Calculator results
#'
#' @export
get_ffc_results_for_usgs_gage <- function(gage_id){
  gage = USGSGage$new()
  gage$id <- gage_id
  gage$get_data()
  return(get_ffc_results_for_df(flows_df, comid = gage$comid))
}

