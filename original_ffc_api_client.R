# Written beginning October 30, 2019 by Daniel Philippus for the LA River Environmental Flows project
# at the Colorado School of Mines.
#
# This program is an R interface to the (environmental) functional flows calculator (hence "r-eff" -> "referee").
# It uses Reticulate to use functions from the EFF's Python codebase, with the intended workflow of putting in
# a data frame and getting out a data frame.  Since EFF works through CSV files, the easiest way to do this is
# to write a CSV, run EFF on it, and then read the resulting CSVs.
if(!require(httr)){
  install.packages("httr")
}
if(!require(jsonlite)){
  install.packages("jsonlite")
}
if(!require(dplyr)){
  install.packages("dplyr")
}


library(httr)
library(jsonlite)
library(dplyr)

TOKEN <- ""  # replace with value of localStorage.getItem('ff_jwt') run from firefox console after logging into eflows.ucdavis.edu

example_gagedata <- function(startdate = "2009/10/01", stopdate = "2019/10/01", mean = 100, sd = 50, gages = 1:10) {
  # Written beginning October 30, 2019 by Daniel Philippus for the LA River Environmental Flows project
  # at the Colorado School of Mines.
  result <- data.frame()
  dates <- format(as.Date(as.Date(startdate):as.Date(stopdate), origin = "1970/01/01"), format = "%m/%d/%Y")
  nflows <- length(dates)
  for (gage in gages) {
    gn = as.character(gage)
    gmean <- rnorm(1, mean, sd)
    gmean <- if (gmean > 0) gmean else 0
    df <- data.frame(gage = gn, date = dates)
    flows <- rnorm(nflows, gmean, sd)
    flows <- vapply(flows, function(x) {if (x > 0) x else 0 }, 1)
    df$flow <- flows
    result <- rbind(result, df)
  }
  result$gage <- as.character(result$gage)
  result
}

make_json <- function(flows_df, start_date, token, name){
  # Prepares the JSON payload to send to the eflows website.
  flows <- jsonlite::toJSON(flows_df$flow)
  dates <- jsonlite::toJSON(flows_df$date)
  extra <- paste(',"name":"', name, '","params":{"general_params":{"annual_result_low_Percentille_filter":0,"annual_result_high_Percentille_filter":100,"max_nan_allowed_per_year":100},"fall_params":{"max_zero_allowed_per_year":270,"max_nan_allowed_per_year":100,"min_flow_rate":1,"broad_sigma":15,"wet_season_sigma":12,"peak_sensitivity":0.005,"peak_sensitivity_wet":0.005,"max_flush_duration":40,"min_flush_percentage":0.1,"wet_threshold_perc":0.2,"peak_detect_perc":0.3,"flush_threshold_perc":0.3,"date_cutoff":75},"spring_params":{"max_zero_allowed_per_year":270,"max_nan_allowed_per_year":100,"max_peak_flow_date":350,"search_window_left":20,"search_window_right":50,"peak_sensitivity":0.1,"peak_filter_percentage":0.5,"min_max_flow_rate":0.1,"window_sigma":10,"fit_sigma":1.3,"sensitivity":0.2,"min_percentage_of_max_flow":0.5,"lag_time":4,"timing_cutoff":138,"min_flow_rate":1},"summer_params":{"max_zero_allowed_per_year":270,"max_nan_allowed_per_year":100,"sigma":7,"sensitivity":900,"peak_sensitivity":0.2,"max_peak_flow_date":325,"min_summer_flow_percent":0.125,"min_flow_rate":1},"winter_params":{"max_zero_allowed_per_year":270,"max_nan_allowed_per_year":100}},"location":"test2","riverName":"test2"', sep="")
  flows_json <- paste('{"ff_jwt":"', token, '", "flows":', flows, ', "dates": ', dates, ', "start_date": "', start_date, '"', extra, '}', sep="")
  return(flows_json)
}

process_data <- function(flows_df, start_date, name){
  # Sends flow timeseries data off to the functional flows calculator. Does *not* retrieve results!
  token = TOKEN  # this would normally be an argument to this function
  flows_json <- make_json(flows_df, start_date, token = token, name=name)
  response <- httr::POST('https://eflows.ucdavis.edu/api/uploadData', httr::content_type("application/json"), body=flows_json)
  httr::stop_for_status(response)
}

get_results_for_name <- function(name){
  # Gets the results for the given named run of the FFC. Returns the nested list - no other processing
  token = TOKEN  # this would normally be an argument to this function
  flows_json <- make_json(NULL, NULL, token = token, name=name)
  response_data <- httr::POST('https://eflows.ucdavis.edu/api/user/get_user_uploads', httr::content_type("application/json"), body=flows_json)
  httr::stop_for_status(response_data)
  results <- httr::content(response_data, "parsed", "application/json")
  
  for (row in results$rows){
    if (row$name == name){
      return(row)
    }
  }
}

get_drh_for_name <- function(name){
  # Pulls the DRH data for a named result and transforms it into a data frame that can be used for plotting and analysis
  results <- get_results_for_name(name)  # get the DRH for this particular result
  drh <- t(do.call(rbind.data.frame, results$DRH))  # rowbind, but transpose
  rownames(drh) <- seq(1,366)  # reset the rownames to days
  return(data.frame(drh))  # convert to data frame and return
}