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
pkg.env$CONSISTENT_NAMING <- FALSE  # when TRUE, we'll update the Peak metric names to include _Mag for internal consistentcy - see https://github.com/ceff-tech/ffc_api_client/issues/44
pkg.env$FILTER_TIMESERIES <- TRUE  # should we filter timeseries - assigned to FFCProcessor - default is in here so we can disable for testing
pkg.env$FAIL_YEARS_DATA <- 10  # how many years of data do we require to proceed? assigned to FFCProcessor - default here so we can lower it during testing

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


#' Set Preference to Rename Metrics Consistently
#'
#' The Peak Magnitude flow metrics are named Peak_2, Peak_5, and Peak_10, while other flow metrics
#' for magnitude use a Component_Mag format. Setting this preference forces all peak metrics
#' to use the naming Peak_Mag_2, Peak_Mag_5, and Peak_Mag_10. This is inconsistent with
#' CEFF, but internally consistent with metric names. The default behavior is not to do this.
#'
#' To use, run force_consistent_naming(TRUE). Then, any function that returns metrics from a
#' FFCProcessor object (includes the FFCProcessor itself and all evaluate_alteration functions - in the
#' future should be any exported function) will rename the peak metrics.
#' To turn off, run force_consistent_naming(FALSE).
#'
#' @param force_to boolean Set to TRUE to enable metric renaming. Set to FALSE to disable it.
#'
#' @export
force_consistent_naming <- function(force_to){
  if(missing(force_to)){
    force_to <- TRUE
  }

  pkg.env$CONSISTENT_NAMING <- force_to
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
evaluate_timeseries_alteration <- function (timeseries_data, comid, plot_output_folder, date_format_string, plot_results, return_processor){
  if(missing(plot_output_folder) || is.null(plot_output_folder)){
    plot_output_folder <- NULL
    drh_output_path <- NULL
  }else{
    drh_output_path <- paste(plot_output_folder, "drh.png", sep="/")
  }

  if(missing(date_format_string)){
    date_format_string <- "%m/%d/%Y"
  }

  if(missing(plot_results)){
    plot_results <- TRUE
  }

  processor <- FFCProcessor$new()
  processor$set_up(timeseries = timeseries_data, comid = comid, token = get_token())
  processor$date_format_string = date_format_string
  processor$run()

  if(plot_results){
    plot_drh(processor$raw_ffc_results, output_path = drh_output_path)
    plot_comparison_boxes(processor$ffc_percentiles, processor$predicted_percentiles, output_folder = plot_output_folder)
  }

  if(return_processor){
    return(processor)
  }else{
    return(list(
      "ffc_results" = processor$ffc_results,
      "ffc_percentiles" = processor$ffc_percentiles,
      "drh_data" = get_drh(processor$raw_ffc_results),
      "predicted_percentiles" = processor$predicted_percentiles,
      "predicted_wyt_percentiles" = processor$predicted_wyt_percentiles,
      "alteration" = processor$alteration
    ))
  }
}

# Converts dates from the provided format string into the format used by the FFC online
convert_dates <- function(timeseries_data, date_format_string){
  timeseries_dates <- strptime(as.character(timeseries_data$date), format = date_format_string)
  timeseries_data$date <- strftime(timeseries_dates, "%m/%d/%Y")
  return(timeseries_data)
}


rename_inconsistent_percentile_metrics <- function(metrics_df, column, set_rownames){
  if(missing(set_rownames)){
    set_rownames <- FALSE
  }

  # there's a more efficient way to do this, but this is fine for such a short data frame
  metrics_df[metrics_df[,column] == "Peak_2", column] <- "Peak_Mag_2"
  metrics_df[metrics_df[,column] == "Peak_5", column] <- "Peak_Mag_5"
  metrics_df[metrics_df[,column] == "Peak_10", column] <- "Peak_Mag_10"
  if(set_rownames){
    rownames(metrics_df) <- metrics_df[,column]
  }

  return(metrics_df)
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
#' @details
#'
#' @export
FFCProcessor <- R6::R6Class("FFCProcessor", list(
  token = NA, ##
  start_date = "10/1", ##
  stream_class = NA,
  date_format_string = "%m/%d/%Y",
  date_field = "date",
  flow_field = "flow",
  params = NA,
  comid = NA,
  timeseries = NA,
  gage = NA,  ##
  raw_ffc_results = NA,
  filter_ffc_results = TRUE,  # indicates whether we want to remove anything that's not a flow metric automatically (Julian day results, some diagnostics)
  ffc_results = NA,
  ffc_percentiles = NA,
  predicted_percentiles = NA,
  predicted_wyt_percentiles = NA,
  predicted_percentiles_online = TRUE,  # should we get predicted flow metrics from the online API, or with our offline data?
  doh_data = NA,
  doh_plot = NA,
  plots = NA,
  plot_output_folder = NA,
  alteration = NA,
  fail_years_data = pkg.env$FAIL_YEARS_DATA, # we'll stop processing if we have this many years or fewer after filtering
  warn_years_data = 15,  # we'll warn people if we have this many years or fewer after filtering
  timeseries_enable_filtering = pkg.env$FILTER_TIMESERIES, # should we run the timeseries filtering? Stays TRUE internally, but the flag is here for advanced users
  timeseries_max_missing_days = 7,
  timeseries_max_consecutive_missing_days = 1,
  timeseries_fill_gaps = "no",
  gage_start_date = "", # start_date and end_date are passed straight through to readNWISdv - "" means "retrieve all". Override values should be of the form YYYY-MM-DD
  gage_end_date = "",
  SERVER_URL = 'https://eflows.ucdavis.edu/api/',

  set_up = function(gage_id, timeseries, comid, token){
    if((missing(gage_id) || is.null(gage_id)) && (missing(timeseries) || is.null(timeseries))){
      stop("Need either a gage ID or a timeseries of data to proceed")
    } else if(missing(gage_id) || is.null(gage_id)){
      gage_id <- NA
    } else if(missing(timeseries)){
      timeseries <- NULL
    }

    if((missing(comid) || is.na(comid)) && is.na(gage_id)){
      stop("Must provide a comid when running a non-gage timeseries.")
    }

    if(missing(comid)){
      comid <- NA
    }

    if(missing(token) || is.null(token)){
      stop("Can't run data through the FFC online without a token")
    }

    if(!is.na(gage_id)){
      self$gage <- USGSGage$new()
      self$gage$id <- gage_id
      self$gage$start_date <- self$gage_start_date
      self$gage$end_date <- self$gage_end_date
      self$gage$get_data()  # this could be extra if someone provided gage ID and timeseries - that seems weird though - not adding another conditional - not needed

      if(is.na(comid)){
        self$gage$get_comid()
      } else {
        self$gage$comid <- comid
      }
      self$comid <- self$gage$comid
    } else {
      self$comid <- comid
    }

    if(is.null(timeseries)){
      # means we want to make the gage get it - if it's missing, we must have a gage
      self$timeseries <- self$gage$timeseries_data
    } else {
      self$timeseries <- timeseries
    }

    # START LOGGING CONFIG
    # futile.logger automatically creates a logger namespaced to this package, so we're fine to just configure the
    # root logger if we only care about having a single logger
    # if we have an output folder, then also dump a text file with log info
    if(!is.na(self$plot_output_folder)){
      log_file <- paste(self$plot_output_folder, "/ffc_api_client_log.txt", sep="")
      print(paste("Log file saving to", log_file))
      futile.logger::flog.appender(futile.logger::appender.file(log_file))
    }

    futile.logger::flog.info(paste("ffcAPIClient Version", packageVersion("ffcAPIClient")))

    if(self$timeseries_enable_filtering){ # this will *always* trigger by default, but is here so advanced users can turn it off if they want
      self$timeseries <- filter_timeseries(self$timeseries,
                                         date_field = self$date_field,
                                         flow_field = self$flow_field,
                                         date_format_string = self$date_format_string,
                                         max_missing_days = self$timeseries_max_missing_days,
                                         max_consecutive_missing_days = self$timeseries_max_consecutive_missing_days,
                                         fill_gaps = self$timeseries_fill_gaps)

      # these stay in the conditional because they rely on the attachment of "water_year"
      # there will now be a water_year field - check how many years we have
      number_of_years <- length(unique(self$timeseries$water_year))
      if(number_of_years <= self$fail_years_data){
        error_message <- paste("Can't proceed - too few water years (", number_of_years, ") remaining after filtering to complete years.", sep="")
        futile.logger::flog.error(error_message)
        stop(error_message)
      }
      if(number_of_years <= self$warn_years_data){
        warn_message <- paste("Timeseries dataframe has a low number of water years(", number_of_years, ") - peak metrics may be unreliable", sep="")
        futile.logger::flog.warn(warn_message)
      }

    }

    self$token <- token
  },

  # we'll have it actually run everything, then for the steps, it'll just return derived outputs like plots, tables, save csvs, etc
  run = function(){
    futile.logger::flog.info(paste("Using date format string", self$date_format_string))

    predicted_percentiles <- get_predicted_flow_metrics(self$comid, online = self$predicted_percentiles_online, wyt = "any")
    if(self$predicted_percentiles_online){  # split them out so that we have the normal predicted percentiles with old-school behavior, and then one with just the WYT records
      self$predicted_percentiles <- predicted_percentiles[predicted_percentiles$wyt == "all",]
      self$predicted_wyt_percentiles <- predicted_percentiles[predicted_percentiles$wyt != "all",]
      self$predicted_percentiles <- self$predicted_percentiles[!names(predicted_percentiles) %in% c("wyt")]  # now drop the ffm column
    } else {
      self$predicted_percentiles <- predicted_percentiles
    }

    timeseries_data <- convert_dates(self$timeseries, self$date_format_string)  # standardize the dates based on the format string
    timeseries_data <- timeseries_data[, which(names(timeseries_data) %in% c(self$date_field, self$flow_field))]  # subset to only these fields so we can run complete cases
    timeseries_data <- timeseries_data[complete.cases(timeseries_data),]  # remove records where date or flows are NA

    self$raw_ffc_results <- get_ffc_results_for_df(timeseries_data, self$comid, flow_field = self$flow_field, date_field = self$date_field, start_date = self$start_date)
    self$ffc_results <- get_results_as_df(self$raw_ffc_results)
    if(self$filter_ffc_results){  # if we want to filter the results, then remove anything that's not a true flow metric
      columns <- colnames(self$ffc_results)
      cols_to_keep <- !grepl("_Julian|__", columns)
      self$ffc_results <- self$ffc_results[, cols_to_keep]
    }

    self$rename_inconsistent_metrics()  # checks if it needs to do things on its own to keep a consistent interface

    self$ffc_percentiles <- get_percentiles(self$ffc_results, comid = self$comid)
    self$alteration <- assess_alteration(percentiles = self$ffc_percentiles,
                                    predictions = self$predicted_percentiles,
                                    ffc_values = self$ffc_results,
                                    comid = self$comid,
                                    annual = FALSE)  # right now, hard code that annual is FALSE - will probably want to change it later
    self$doh_data <- get_drh(self$raw_ffc_results)
  },

  rename_inconsistent_metrics = function(){
    if(!pkg.env$CONSISTENT_NAMING){  # if the preference to rename metrics is FALSE, just end this function
      return()
    }
    names(self$ffc_results)[names(self$ffc_results) == 'Peak_2'] <- 'Peak_Mag_2'
    names(self$ffc_results)[names(self$ffc_results) == 'Peak_5'] <- 'Peak_Mag_5'
    names(self$ffc_results)[names(self$ffc_results) == 'Peak_10'] <- 'Peak_Mag_10'

    self$predicted_percentiles <- rename_inconsistent_percentile_metrics(self$predicted_percentiles, "metric", set_rownames = TRUE)
    if(self$predicted_percentiles_online){
      self$predicted_wyt_percentiles <- rename_inconsistent_percentile_metrics(self$predicted_wyt_percentiles, "metric", set_rownames = FALSE)
    }

  },

  #' @details
  #' Get Gage ID for FFCProcessor
  #'
  #' We may not always have a gage ID, but may want to just get one if it exists - this function gets a gage ID if we're using a gage
  #' or returns NA otherwise
  get_gage_id = function(){
    return(tryCatch(self$gage$id, error = function (cond){return(NA)}))
  },

  # CEFF step 1
  step_one_functional_flow_results = function(gage_id, timeseries, comid, token, output_folder){
    if(missing(gage_id) && missing(timeseries)){
      stop("Must provide either a gage_id or a timeseries data frame to proceed.")
    }

    if(missing(comid)){  # this will get tested properly when we run set_up
      comid <- NA
    }

    if(missing(output_folder)){
      output_folder <- NA
    }else{
      if(!dir.exists(output_folder)){
        dir.create(output_folder)
      }
    }

    set_token(token)

    self$plot_output_folder <- output_folder

    futile.logger::flog.info("### Step 1 - Get Functional Flow Results ###")

    futile.logger::flog.info("Retrieving results, please wait...")
    self$set_up(gage_id, timeseries, comid, token)
    self$run()
    futile.logger::flog.info("Results ready.")
    futile.logger::flog.info(paste("Writing FFC results as CSVs to ", output_folder, sep=""))
    write.csv(self$ffc_percentiles, paste(output_folder, "/", self$comid, "_", "ffc_percentiles.csv", sep=""))
    write.csv(self$ffc_results, paste(output_folder, "/", self$comid, "_", "ffc_results.csv", sep=""))
    write.csv(self$doh_data, paste(output_folder, "/", self$comid, "_", "doh_data.csv", sep=""))

    futile.logger::flog.info(paste("Writing observed plots to ", output_folder, sep=""))
    self$doh_plot <- plot_drh(self$raw_ffc_results, paste(output_folder, "/", self$comid, "_", "DOH.png", sep=""))
    show(self$doh_plot)
    gage_id <- self$get_gage_id()

    plot_comparison_boxes(self$ffc_percentiles, self$predicted_percentiles, output_folder, gage_id = gage_id, name_suffix = "_observed_only", use_dfs="observed")

    futile.logger::flog.info("Printing Observed/FFC Percentiles. You can also access attributes $ffc_results on this object for the annual values for each metric, $ffc_percentiles for calculated percentile values, and $doh_data for the Dimensionless Observed Hydrograph data.")
    futile.logger::flog.info(self$ffc_percentiles)

    futile.logger::flog.info("Step 1 complete")
  },

  # CEFF step 2
  step_two_explore_ecological_flow_criteria = function(){
    futile.logger::flog.info("### Step 2 - Explore Ecological Flow Criteria ###")
    gage_id <- self$get_gage_id()

    futile.logger::flog.info("Printing Predicted Percentiles. You can also access attributes $predicted_percentiles on this object for these data.")
    futile.logger::flog.info(self$predicted_percentiles)

    futile.logger::flog.info(paste("Writing Predicted Percentiles as CSV to ", self$plot_output_folder, sep=""))
    write.csv(self$predicted_percentiles, paste(self$plot_output_folder, "/", self$comid, "_", "predicted_percentiles.csv", sep=""))

    futile.logger::flog.info(paste("Writing predicted metric plots to ", self$plot_output_folder, sep=""))
    plot_comparison_boxes(self$ffc_percentiles, self$predicted_percentiles, self$plot_output_folder, gage_id = gage_id, name_suffix = "_predicted_only", use_dfs="predicted")

    futile.logger::flog.info("Step 2 complete")
  },

  # CEFF step 3/
  step_three_assess_alteration = function(){
    futile.logger::flog.info("### Step 3 - Assess Alteration ###")
    gage_id <- self$get_gage_id()

    futile.logger::flog.info("Printing alteration assessment data. You can also access attributes $alteration on this object for these data")
    futile.logger::flog.info(self$alteration)

    futile.logger::flog.info(paste("Writing alteration assessment as CSV to ", self$plot_output_folder, sep=""))
    write.csv(self$alteration, paste(self$plot_output_folder, "/", self$comid, "_", "alteration.csv", sep=""))

    futile.logger::flog.info(paste("Writing comparison plots to ", self$plot_output_folder, sep=""))
    plot_comparison_boxes(self$ffc_percentiles, self$predicted_percentiles, self$plot_output_folder, gage_id = gage_id)

    futile.logger::flog.info("Step 3 complete")
  },

  get_ffc_results = function(){
    if(is.na(self$token)){
      stop("Token not provided - can't proceed. Set the token on the class before proceeding")
    }

    # TODO - check to make sure we have everything we need first
    set_token(self$token)
    results <- evaluate_timeseries_alteration(timeseries_data = timeseries, predictions_df = predictions)
    self$drh_data <- results$drh_data
    self$percentiles <- results$percentiles
    ffc_results <- results$ffc_results_df

    invisible(self)
  },

  #' @details
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
