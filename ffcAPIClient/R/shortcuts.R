
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
#' 5. Produce percentiles for those metric values using R's recommended quantile method type 7 (which may return differing results from other methods, Excel, etc)
#'
#' 6. Transform the dimensionless reference hydrograph data into a data frame
#'
#' 7. Determines the alteration by flow metric for the observed versus predicted values
#'
#' 8. Output plots comparing the observed timeseries data with the predicted unimpaired metric values.
#'
#' Items 4, 5, 6, and 7 are returned back to the caller as a list with keys "ffc_results", "ffc_percentiles", "drh_data", and "alteration"
#' for any further processing. The list also includes "predicted_percentiles", with the predicted flow metrics for the segment.
#'
#' @param gage_id The USGS gage ID to pull timeseries data from
#' @param token The token used to access the online FFC - see the Github repository's README under Setup for how to get this.
#' @param comid The stream segment COMID where the gage is located. In the past, the package looked this information up automatically
#'        but we discovered that our method for looking gage COMIDs up was error prone, and there is no authoritative dataset
#'        that relates gages to COMIDs. It will be most accurate if you provide the comid yourself by looking it up (don't
#'        use nhdPlusTools with the latitude and longitude - that's what we did that was error prone). You can re-enable
#'        the lookup behavior setting the \code{force_comid_lookup} parameter to \code{TRUE}.
#' @param plot_output_folder Optional - when not provided, plots are displayed interactively only. When provided, they are
#'        displayed interactively and saved as files named by the functional flow componenent into the provided folder
#' @param plot_results boolean, default \code{TRUE} - when \code{TRUE}, results are plotted to the screen and any folder provided. When
#'        FALSE, does no plotting.
#' @param force_comid_lookup default \code{FALSE}. When \code{TRUE}, the COMID for the segment will be automatically
#'        looked up based on the latitude and longitude. This method is error prone and it is advised you leave it off.
#'        Where an error is known, the package corrects the COMID based on an internal list of gage/comid pairs (eg:
#'        Jones Bar on the Yuba River). It is recommended you leave this as FALSE and look up the comid yourself to
#'        ensure that you choose the correct mainstem or tributary near stream junctions, but if you need to bulk
#'        process data, this parameter is available to retrieve COMIDs.
#'
#' @export
evaluate_gage_alteration<- function (gage_id, token, comid, plot_output_folder, plot_results, force_comid_lookup){
  if(missing(plot_output_folder)){
    plot_output_folder <- NULL
  }

  if(missing(plot_results)){
    plot_results <- TRUE
  }

  if(missing(force_comid_lookup)){
    force_comid_lookup <- FALSE
  }

  if(missing(comid)){
    if(!force_comid_lookup){
      stop("Must provide parameter comid or enable comid lookup (see documentation for issues first!) with force_comid_lookup.")
    }
    comid <- NA
  }

  set_token(token)
  gage <- USGSGage$new()
  gage$id <- gage_id
  gage$get_data()
  gage$comid <- comid
  predictions_df <- gage$get_predicted_metrics(force_comid_lookup = force_comid_lookup)

  results_list <- evaluate_timeseries_alteration(gage$timeseries_data, gage$comid, predictions_df, plot_output_folder = plot_output_folder, plot_results = plot_results)

  results_list$ffc_percentiles["gage_id"] <- gage_id
  results_list$predicted_percentiles["gage_id"] <- gage_id
  results_list$alteration["gage_id"] <- gage_id

  return(results_list)
}


#' Generate FFC Results and Plots for Timeseries Data
#'
#' Processes timeseries data using the functional flows calculator and returns results for metric percentiles, annual metric values,
#' predicted metric values, flow alteration, and drh data.
#'
#' See the documentation for \code{evaluate_gage_alteration} for complete details on the processing and what is returned.
#'
#' @param timeseries_df A timeseries dataframe that includes fields named "flow" and "date" for each record. Date should either
#'        be in MM/DD/YYYY format, or parameter \code{date_format_string} must be specified. The data frame may include other fields,
#'        which will be automatically dropped when sent to the FFC.
#' @param token The token used to access the online FFC - see the Github repository's README under Setup for how to get this.
#' @param comid The stream segment COMID where the gage is located. You may also have the package look this information up automatically
#'        based on longitude and latitude, but we discovered that our method for looking gage COMIDs up is error prone,
#'        and there is no authoritative dataset that relates gages to COMIDs correctly. It will be most accurate if you
#'        provide the comid yourself by looking it up (don't use nhdPlusTools with the latitude and longitude
#'        that's what we did that was error prone).
#' @param longitude the longitude of the location the flow data were collected at.
#' @param latitude the latitude of the location the flow data were collected at. If both longitude and latitude are defined, then
#'        and parameter comid is missing, then the COMID will be looked up. See notes on parameter comid for cautions and limitations.
#' @param plot_output_folder Optional - when not provided, plots are displayed interactively only. When provided, they are
#'        displayed interactively and saved as files named by the functional flow componenent into the provided folder
#' @param plot_results boolean, default \code{TRUE} - when \code{TRUE}, results are plotted to the screen and any folder provided. When
#'        FALSE, does no plotting.
#'
#' @export
evaluate_alteration <- function(timeseries_df, token, comid, longitude, latitude, plot_output_folder, plot_results, date_format_string){
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

  if(missing(plot_results)){
    plot_results <- TRUE
  }

  if(missing(date_format_string)){
    print("Using default date format string of %m/%d/%Y")
    date_format_string <- "%m/%d/%Y"
  }

  set_token(token)
  predicted_flow_metrics <- get_predicted_flow_metrics(comid)
  results_list <- evaluate_timeseries_alteration(timeseries_df, comid, predicted_flow_metrics, plot_output_folder, date_format_string, plot_results = plot_results)
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

