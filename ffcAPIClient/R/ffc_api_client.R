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


# Send flow data for processing
#
# In most cases, you won't need to use this function! If you're wondering what to do, use
# get_ffc_results_for_df instead.
# Sends flow timeseries data off to the functional flows calculator. Does not retrieve results!
#
process_data <- function(flows_df, params, flow_field, date_field, start_date, name){
  creation_params <- paste(',"name":"', name, '","params":', params, sep="")
  data_json <- make_flow_json(flows_df, flow_field, date_field)
  flows_json <- make_json(data_json, start_date, token = pkg.env$TOKEN, extra = creation_params)
  #return(flows_json)

  endpoint <- paste(pkg.env$SERVER_URL,'uploadData', sep="")
  response <- httr::POST(endpoint, httr::content_type("application/json"), body=flows_json)
  httr::stop_for_status(response)

  return(flows_json)
}

# Retrieve processed results from FFC.
#
# Gets the results for the given named run of the FFC. Returns the nested list - all other processing must be handled
# by the caller.
#
# @param name the name of the run to retrieve from the online FFC
# @param autodelete when TRUE, deletes the run in the online FFC, if found. When FALSE, leaves run in FFC online for later
#        retrieval.
#
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


# Run Data Frame Through Functional Flows Calculator
#
# This is primarily an internal function used to run data through the functional flows
# calculator online, but is also available for those that wish to run the data themselves
# and then do any other handling and transformation for postprocessing on their own.
#
# Most people will want to use \code{\link{evaluate_alteration}} (for timeseries dataframes)
# or \code{\link{evaluate_gage_alteration}} (for USGS gages) instead.
#
# Internally, this is the primary function to use from the API client itself to obtain
# raw FFC results. It will generate a unique ID, run the data frame through
# the FFC, and then delete the results for that ID from the website so as not
# to clutter up the user's account, or store too much data on the server side.
#
# @param flows_df DataFrame. A time series data frame with flow and date columns
# @param comid character. The COMID of the stream segment
# @param flow_field character, default "flow". The name of the field in \code{df} that contains
#         flow values.
# @param date_field character, default "date". The name of the field in \code{df} that contains
#         date values for each flow. The date field must be in MM/DD/YYYY format
#         as either factor or character values - true dates likely will not work
#         based on the API we're using. If you need to convert date values, add
#         a field to your existing data frame with the values in MM/DD/YYYY format
#         before providing it to this function.
# @param start_date character, default "10/1". What month and day should the water
#         year start on? Neither month nor day needs to be zero-padded here, so
#         March first could just be 3/1, while December 12th can be 12/12.
# @return list of results from the functional flows calculator. More information will be
#         forthcoming as we inspect the structure of what is returned.
#
get_ffc_results_for_df <- function(flows_df, comid, flow_field, date_field, start_date){
  if(missing(flow_field)){
    flow_field = "flow"  # this value is compatible with what you'd upload to the web interface
  }
  if(missing(date_field)){
    date_field = "date"  # this value is compatible with what you'd upload to the web interface
  }
  if(missing(start_date)){
	  start_date = "10/1"  # default to the beginning of the water year
  }
  if(missing(comid)){
    params <- get_ffc_parameters_for_comid_as_json(00000000)  # if the COMID isn't provided, send a invalid one through - it'll return the general params
  }else{
    params <- get_ffc_parameters_for_comid_as_json(comid)
  }


  # we'll use a UUID for this because we want to make sure we don't collide with anything else the user already has in the FFC online
  id = uuid::UUIDgenerate()

  process_data(flows_df, params, flow_field = flow_field, date_field = date_field, start_date = start_date, name = id)
  return(get_results_for_name(id))
}



# Does the bulk of the processing, but not a public function - both other evaluate_alteration functions use this under
# the hood after doing some other checks, etc.
evaluate_timeseries_alteration <- function (timeseries_data, comid, predictions_df, plot_output_folder, date_format_string, plot_results){
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

  if(missing(plot_results)){
    plot_results <- TRUE
  }

  timeseries_data <- convert_dates(timeseries_data, date_format_string)  # standardize the dates based on the format string
  timeseries_data <- timeseries_data[, which(names(timeseries_data) %in% c("date", "flow"))]  # subset to only these fields so we can run complete cases
  timeseries_data <- timeseries_data[complete.cases(timeseries_data),]  # remove records where date or flows are NA

  ffc_results <- get_ffc_results_for_df(timeseries_data, comid)
  results_df <- get_results_as_df(ffc_results)
  percentiles <- get_percentiles(results_df, comid = comid)
  alteration <- assess_alteration(percentiles = percentiles,
                                  predictions = predictions_df,
                                  ffc_values = results_df,
                                  comid = comid,
                                  annual = FALSE)  # right now, hard code that annual is FALSE - will probably want to change it later
  if(plot_results){
    plot_drh(ffc_results, output_path = drh_output_path)
    plot_comparison_boxes(percentiles, predictions_df, output_folder = plot_output_folder)
  }
  return(list(
    "ffc_results" = results_df,
    "ffc_percentiles" = percentiles,
    "drh_data" = get_drh(ffc_results),
    "predicted_percentiles" = predictions_df,
    "alteration" = alteration
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
  token = NA, ##
  start_date = "10/1", ##
  stream_class = NA,
  params = NA,
  comid = NA,
  timeseries = NA,
  gage = NA,  ##
  ffc_results = NA,
  percentiles = NA,
  predictions = NA,
  prediction_percentiles_type = "offline",
  drh_data = NA,
  plots = NA,
  plot_output_folder = NA,
  alteration = NA,
  SERVER_URL = 'https://eflows.ucdavis.edu/api/',

  setup = function(gage_id, timeseries, comid, token){
    if(missing(gage_id) && missing(timeseries)){
      stop("Need either a gage ID or a timeseries of data to proceed")
    } else if(missing(gage_id)){
      gage_id <- NA
    } else if(missing(timeseries)){
      timeseries <- NA
    }

    if(missing(comid) && is.na(gage_id)){
      stop("Must provide a comid when running a non-gage timeseries.")
    }

    if(missing(token)){
      stop("Can't run data through the FFC online without a token")
    }

    self$gage <- USGSGage$new()
    self$gage$id <- gage_id
    self$gage$comid <- comid

    self$timeseries <- timeseries
    self$token <- token

  },

  # we'll have it actually run everything, then for the steps, it'll just return derived outputs like plots, tables, save csvs, etc
  run = function(){

  },

  # CEFF step 1
  generate_functional_flow_results = function(){

  },

  # CEFF step 2
  explore_ecological_flow_criteria = function(){

  },

  # CEFF step 3
  assess_alteration = function(){

  },

  get_ffc_results = function(){
    if(is.na(self$token)){
      stop("Token not provided - can't proceed. Set the token on the class before proceeding")
    }

    # TODO - check to make sure we have everything we need first
    set_token(self$token)
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
    metrics <- self$predictions$metrics

    # need a function that takes one metric's percentiles, predictions, and raw ffc values and returns a metric, alteration type, and text description ("likely unaltered", "likely altered", etc)
    # then we can run an apply operation, rbind the results back together, save them on the object and return them

    invisible(self)
  }
))
