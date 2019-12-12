# Nick Santos, UC Davis Center for Watershed Sciences, December 2019

#' ffcAPIClient: Processes time-series flow data using the online functional
#' flows calculator
#'
#' For now, see the documentation for \code{\link{get_ffc_results_for_df}}
#'
#' @examples
#' # Example 1
#' ## Initialize a Run
#' test_data <- example_gagedata()  # just get some fake gage data - based on Daniel Philippus' code - you can build your own data frame here
#' ffcAPIClient::set_token(YOUR_TOKEN_VALUE_IN_QUOTES)  # you'll need to get your own of this - see above
#' results <- ffcAPIClient::get_ffc_results_for_df(test_data)  # send it to the FFC online to process
#'
#' ## Retrieve Results and Plot
#' ## get the DRH data as a data frame with percentiles for columns and days for rows
#' drh_data <- ffcAPIClient::get_drh(results)
#' plot(drh_data$seventy_five, type="l")  # plot the seventy-fifth percentile DRH
#'
#' # Example 2: Retrieve, Process, Plot USGS gage
#' ## This example retrieves USGS gage data, runs it through the FFC online, and plots the DRH nicely
#' ## don't forget to set your token first if you haven't already
#' ffcAPIClient::set_token(YOUR_TOKEN_VALUE_IN_QUOTES) # you'll need to get your own of this - see above
#'
#' ## retrieves flow data for North Fork American gage and sends it through the FFC
#' results <- get_ffc_results_for_usgs_gage(11427000)
#' drh_plot <- ffcAPIClient::plot_drh(results)  # includes optional output_path argument to save to file automatically
#' drh_plot  # display the plot
#'
#' @docType package
#' @name ffcAPIClient
NULL

pkg.env <- new.env(parent=emptyenv())  # set up a new environment to store the token
pkg.env$TOKEN <- "" # initialize the empty token
pkg.env$SERVER_URL <- 'https://eflows.ucdavis.edu/api/'

#' Set Eflows Website Access Token
#'
#' Provide the token string used for accessing the Eflows site. A token is a
#' method of authorization for identifying your user account within scripts.
#' By providing the token, this package uses your user account when interacting
#' with the eflows web service/API.
#'
#' @param token_string character
#' @export
#'
#' This is a function so that it can set the package private TOKEN variable.
set_token <-function(token_string){
  pkg.env$TOKEN <- token_string
}

#' Retrieve Previously Set Token
#'
#' Retrieves the authorization token previously set by set_token in the same R session.
#' @export
get_token <- function(){
  return(pkg.env$TOKEN)
}

#' Makes the part of the JSON string that is just for the flow data - needs to be passed
#' into make_json later as "data_json"
make_flow_json <- function(flows_df, flow_field, date_field){
  flows <- jsonlite::toJSON(flows_df[[flow_field]])
  dates <- jsonlite::toJSON(flows_df[[date_field]])

  flow_json <- paste(', "flows":', flows, ', "dates": ', dates, sep="")
  return(flow_json)
}


#' Prepares the JSON payload to send to the eflows website.
make_json <- function(data_json, start_date, token, extra){
  flows_json <- paste('{"ff_jwt":"', token, '"', data_json, ', "start_date": "', start_date, '"', extra, '}', sep="")
  return(flows_json)
}


#' Send flow data for processing
#'
#' In most cases, you won't need to use this function! If you're wondering what to do, use
#' get_ffc_results_for_df instead.
#'
#' Sends flow timeseries data off to the functional flows calculator. Does not retrieve results!
#'
#' @export
process_data <- function(flows_df, flow_field, date_field, start_date, name){
  creation_params <- paste(',"name":"', name, '","params":{"general_params":{"annual_result_low_Percentille_filter":0,"annual_result_high_Percentille_filter":100,"max_nan_allowed_per_year":100},"fall_params":{"max_zero_allowed_per_year":270,"max_nan_allowed_per_year":100,"min_flow_rate":1,"broad_sigma":15,"wet_season_sigma":12,"peak_sensitivity":0.005,"peak_sensitivity_wet":0.005,"max_flush_duration":40,"min_flush_percentage":0.1,"wet_threshold_perc":0.2,"peak_detect_perc":0.3,"flush_threshold_perc":0.3,"date_cutoff":75},"spring_params":{"max_zero_allowed_per_year":270,"max_nan_allowed_per_year":100,"max_peak_flow_date":350,"search_window_left":20,"search_window_right":50,"peak_sensitivity":0.1,"peak_filter_percentage":0.5,"min_max_flow_rate":0.1,"window_sigma":10,"fit_sigma":1.3,"sensitivity":0.2,"min_percentage_of_max_flow":0.5,"lag_time":4,"timing_cutoff":138,"min_flow_rate":1},"summer_params":{"max_zero_allowed_per_year":270,"max_nan_allowed_per_year":100,"sigma":7,"sensitivity":900,"peak_sensitivity":0.2,"max_peak_flow_date":325,"min_summer_flow_percent":0.125,"min_flow_rate":1},"winter_params":{"max_zero_allowed_per_year":270,"max_nan_allowed_per_year":100}},"location":"test2","riverName":"test2"', sep="")
  data_json <- make_flow_json(flows_df, flow_field, date_field)
  flows_json <- make_json(data_json, start_date, token = pkg.env$TOKEN, extra = creation_params)

  endpoint <- paste(pkg.env$SERVER_URL,'uploadData', sep="")
  response <- httr::POST(endpoint, httr::content_type("application/json"), body=flows_json)
  httr::stop_for_status(response)

  return(flows_json)
}

#' Retrieve processed results from FFC.
#'
#' In most cases, you won't need to use this function! If you're wondering what to do, use
#' get_ffc_results_for_df instead.
#'
#' Gets the results for the given named run of the FFC. Returns the nested list - no other processing
#' @export
get_results_for_name <- function(name, autodelete){

  if(missing(autodelete)){
    autodelete = TRUE
  }


  flows_json <- make_json(NULL, NULL, token = pkg.env$TOKEN, extra = "")

  endpoint <- paste(pkg.env$SERVER_URL, 'user/get_user_uploads', sep="")
  response_data <- httr::POST(endpoint, httr::content_type("application/json"), body=flows_json)
  httr::stop_for_status(response_data)
  results <- httr::content(response_data, "parsed", "application/json")

  for (row in results$rows){
    if (row$name == name){
      if (autodelete == TRUE){
        delete_ffc_run_by_id(row$id)  # remove the run from the FFC online so it doesn't balloon on us
      }
      return(row)
    }
  }
}



delete_ffc_run_by_id <- function(id){

  json <- make_json(NULL, NULL, pkg.env$TOKEN, extra=paste(', "id":', id, sep=""))
  endpoint <- paste(pkg.env$SERVER_URL,'uploadData', sep="")
  httr::DELETE(endpoint, httr::content_type("application/json"), body=json)
}


#' Run Data Frame Through Functional Flows Calculator
#'
#' This is the primary function to use from the API client itself to obtain
#' raw FFC results. It will generate a unique ID, run the data frame through
#' the FFC, and then delete the results for that ID from the website so as not
#' to clutter up the user's account, or store too much data on the server side.
#'
#' @param flows_df DataFrame. A time series data frame with flow and date columns
#' @param flow_field character, default "flow". The name of the field in \code{df} that contains
#'         flow values.
#' @param date_field character, default "date". The name of the field in \code{df} that contains
#'         date values for each flow. The date field must be in MM/DD/YYYY format
#'         as either factor or character values - true dates likely will not work
#'         based on the API we're using. If you need to convert date values, add
#'         a field to your existing data frame with the values in MM/DD/YYYY format
#'         before providing it to this function.
#' @param start_date character, default "10/1". What month and day should the water
#'         year start on? Neither month nor day needs to be zero-padded here, so
#'         March first could just be 3/1, while December 12th can be 12/12.
#' @return list of results from the functional flows calculator. More information will be
#'         forthcoming as we inspect the structure of what is returned.
#' @export
#'
get_ffc_results_for_df <- function(flows_df, flow_field, date_field, start_date){
  if(missing(flow_field)){
    flow_field = "flow"  # this value is compatible with what you'd upload to the web interface
  }
  if(missing(date_field)){
    date_field = "date"  # this value is compatible with what you'd upload to the web interface
  }
  if(missing(start_date)){
	  start_date = "10/1"  # default to the beginning of the water year
  }

  # we'll use a UUID for this because we want to make sure we don't collide with anything else the user already has in the FFC online
  id = uuid::UUIDgenerate()

  process_data(flows_df, flow_field, date_field, start_date = start_date, name = id)
  return(get_results_for_name(id))
}


get_ffc_results_for_usgs_gage <- function(gage_id, start_date){
  if(missing(start_date)){
    start_date = "10/1"  # default to the beginning of the water year
  }

  flows_df <- get_usgs_gage_data(gage_id)
  return(get_ffc_results_for_df(flows_df, start_date=start_date))
}
