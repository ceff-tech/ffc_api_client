# Nick Santos, UC Davis Center for Watershed Sciences, December 2019

#' ffcAPIClient: Processes time-series flow data using the online functional
#' flows calculator
#'
#' For now, see the documentation for \code{\link{evaluate_alteration}} and
#' \code{\link{evaluate_gage_alteration}}
#'
#' @examples
#' \dontrun{
#' # If you have a gage and a token, you can get all results simply by running
#' ffcAPIClient::evaluate_gage_alteration(gage_id = 11427000, token = "your_token", plot_output_folder = "C:/Users/youruser/Documents/NFA_Gage_Alteration")
#' # output_folder is optional. When provided, it will save plots there. It will show plots regardless.
#'
#' # If you have a data frame with flow and date fields that isn't a gage, you can run
#' ffcAPIClient::evaluate_alteration(timeseries_df = your_df, token = "your_token", plot_output_folder = "C:/Users/youruser/Documents/Timeseries_Alteration", comid=yoursegmentcomid)
#' # it also *REQUIRES* you provide either a comid argument with the stream segment COMID, or both
#' # longitude and latitude arguments.
#' # Make sure that dates are in the same format as the FFC requires on its website. We may add reformatting in the future
#'
#' }
#' @docType package
#' @name ffcAPIClient
NULL

pkg.env <- new.env(parent=emptyenv())  # set up a new environment to store the token
pkg.env$TOKEN <- NA # initialize the empty token
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
set_token <-function(token_string){
  pkg.env$TOKEN <- token_string
}

#' Retrieve Previously Set Token
#'
#' Retrieves the authorization token previously set by set_token in the same R session.
#'
#' @export
get_token <- function(){
  return(pkg.env$TOKEN)
}

# Makes the part of the JSON string that is just for the flow data - needs to be passed
# into make_json later as "data_json"
make_flow_json <- function(flows_df, flow_field, date_field){
  flows <- jsonlite::toJSON(flows_df[[flow_field]])
  dates <- jsonlite::toJSON(flows_df[[date_field]])

  flow_json <- paste(', "flows":', flows, ', "dates": ', dates, sep="")
  return(flow_json)
}


# Prepares the JSON payload to send to the eflows website.
make_json <- function(data_json, start_date, token, extra){
  if(is.na(token)){
    stop("Token must be set using set_token(your_token_value) before sending data to FFC API. See README or documentation
         for more information on setting the token.")
  }
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
#' Gets the results for the given named run of the FFC. Returns the nested list - all other processing must be handled
#' by the caller.
#'
#' @param name the name of the run to retrieve from the online FFC
#' @param autodelete when TRUE, deletes the run in the online FFC, if found. When FALSE, leaves run in FFC online for later
#'        retrieval.
#'
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
#' This is primarily an internal function used to run data through the functional flows
#' calculator online, but is also available for those that wish to run the data themselves
#' and then do any other handling and transformation for postprocessing on their own.
#'
#' Most people will want to use \code{\link{evaluate_alteration}} (for timeseries dataframes)
#' or \code{\link{evaluate_gage_alteration}} (for USGS gages) instead.
#'
#' Internally, this is the primary function to use from the API client itself to obtain
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
#'
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
get_ffc_results_for_usgs_gage <- function(gage_id, start_date){
  if(missing(start_date)){
    start_date = "10/1"  # default to the beginning of the water year
  }

  flows_df <- get_usgs_gage_data(gage_id)
  return(get_ffc_results_for_df(flows_df, start_date=start_date))
}

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
#' 5. Produce percentiles for those metric values
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
evaluate_gage_alteration<- function (gage_id, token, plot_output_folder){
  if(missing(plot_output_folder)){
    plot_output_folder <- NULL
  }

  set_token(token)
  gage <- USGSGage$new()
  gage$id <- gage_id
  gage$get_data()
  predictions_df <- gage$get_predicted_metrics()

  results_list <- evaluate_timeseries_alteration(gage$timeseries_data, predictions_df, plot_output_folder)
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
  results_list <- evaluate_timeseries_alteration(timeseries_df, predicted_flow_metrics, plot_output_folder, date_format_string)
  return(results_list)
}

# Does the bulk of the processing, but not a public function - both other evaluate_alteration functions use this under
# the hood after doing some other checks, etc.
evaluate_timeseries_alteration <- function (timeseries_data, predictions_df, plot_output_folder, date_format_string){
  if(missing(plot_output_folder) || is.null(plot_output_folder)){
    plot_output_folder <- NULL
    drh_output_path <- NULL
  }else{
    drh_output_path <- paste(plot_output_folder, "drh.png", sep="/")
  }

  if(missing(date_format_string)){
    print("Using default date format string of %m/%d/%Y")
    date_format_string <- "%m/%d/%Y"
  }

  timeseries_data <- convert_dates(timeseries_data, date_format_string)  # standardize the dates based on the format string
  timeseries_data <- timeseries_data[, which(names(timeseries_data) %in% c("date", "flow"))]  # subset to only these fields so we can run complete cases
  timeseries_data <- timeseries_data[complete.cases(timeseries_data),]  # remove records where date or flows are NA

  ffc_results <- get_ffc_results_for_df(timeseries_data)
  plot_drh(ffc_results, output_path = drh_output_path)
  results_df <- get_results_as_df(ffc_results)
  percentiles <- get_percentiles(results_df)
  plot_comparison_boxes(percentiles, predictions_df, output_folder = plot_output_folder)
  return(list(
    "ffc_results" = results_df,
    "percentiles" = percentiles,
    "drh_data" = get_drh(ffc_results)
  ))
}

# Converts dates from the provided format string into the format used by the FFC online
convert_dates <- function(timeseries_data, date_format_string){
  timeseries_dates <- strptime(as.character(timeseries_data$date), format = date_format_string)
  timeseries_data$date <- strftime(timeseries_dates, "%m/%d/%Y")
  return(timeseries_data)
}


#' FFCProcessor Class
#'
#' The new workhorse of the client - this class is meant to bring together the scattershot functions
#' in other parts of the package so that data can be integrated into a single class with a single
#' set of tasks. Other functions are likely to be supported for a while (and this may even rely on them),
#' but long run, much of the code in this file might move into this class, with the shortcut functions
#' creating this class behind the scenes and returning an instance of this object.
#'
#' More details to come, and more examples. For now, still use the general functions \code{\link{evaluate_alteration}}
#' and \code{\link{evaluate_gage_alteration}}
#'
#' @export
FFCProcessor <- R6::R6Class("FFCProcessor", list(
  token = NA,
  start_date = NA,
  stream_class = NA,
  params = NA,
  comid = NA,
  timeseries = NA,
  gage = NA,
  ffc_results = NA,
  percentiles = NA,
  predictions = NA,
  drh_data = NA,
  plots = NA,
  plot_output_folder = NA,
  alteration = NA,

  get_ffc_results = function(){
    # TODO - check to make sure we have everything we need first
    set_token(token)
    results <- evaluate_timeseries_alteration(timeseries_data = timeseries, predictions_df = predictions)
    self$drh_data <- results$drh_data
    self$perecentiles <- results$percentiles
    ffc_results <- results$ffc_results_df

    invisible(self)
  },

  #' Provides alteration scores
  #'
  #' Checks the results against the predictions and returns the appropriate alteration score
  #'
  evaluate_alteration = function(){
    if(is.na(self$percentiles) || is.na(self$predictions) || is.na(self$ffc_results)){
      stop("Must already have all results from the Functional Flow Calculator and predictions for stream segment to
           evaluate alteration. Make sure that the FFCProcessor has $percentiles, $predictions, and $ffc_results set
           before calling $evaluate_alteration().")
    }
    metrics <- self$predictions$Metrics

    # need a function that takes one metric's percentiles, predictions, and raw ffc values and returns a metric, alteration type, and text description ("likely unaltered", "likely altered", etc)
    # then we can run an apply operation, rbind the results back together, save them on the object and return them

    invisible(self)
  }
))
