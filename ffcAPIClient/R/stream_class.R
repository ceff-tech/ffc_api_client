# parameters by stream class adapted from https://github.com/ceff-tech/eflow-client/blob/master/src/constants/params.js

general_parameters = list(
  "general_params" = list(
    "annual_result_low_Percentille_filter" = 0,
    "annual_result_high_Percentille_filter" = 100,
    "max_nan_allowed_per_year" = 100
  ),
  "winter_params" = list(
    "max_zero_allowed_per_year" = 270,
    "max_nan_allowed_per_year" = 100,
    "broad_sigma" = 15, # fall_params
    "peak_detect_perc" = 0.3, # fall_params
    "wet_threshold_perc" = 0.2, # fall_params
    "peak_sensitivity_wet" = 0.005 # fall_params
  ),
  "fall_params" = list(
    "max_zero_allowed_per_year" = 270,
    "max_nan_allowed_per_year" = 100,
    "min_flow_rate" = 1,
    "broad_sigma" = 15,
    "wet_season_sigma" = 12,
    "peak_sensitivity" = 0.005,
    "peak_sensitivity_wet" = 0.005,
    "max_flush_duration" = 40,
    "min_flush_percentage" = 0.1,
    "wet_threshold_perc" = 0.2,
    "peak_detect_perc" = 0.3,
    "flush_threshold_perc" = 0.3,
    "date_cutoff" = 75
  ),
  "spring_params" = list(
    "max_zero_allowed_per_year" = 270,
    "max_nan_allowed_per_year" = 100,
    "max_peak_flow_date" = 350,
    "search_window_left" = 20,
    "search_window_right" = 50,
    "peak_sensitivity" = 0.1,
    "peak_filter_percentage" = 0.5,
    "min_max_flow_rate" = 0.1,
    "window_sigma" = 10,
    "fit_sigma" = 1.3,
    "sensitivity" = 0.2,
    "min_percentage_of_max_flow" = 0.5,
    "lag_time" = 4,
    "timing_cutoff" = 138,
    "min_flow_rate" = 1
  ),
  "summer_params" = list(
    "max_zero_allowed_per_year" = 270,
    "max_nan_allowed_per_year" = 100,
    "sigma" = 7,
    "sensitivity" = 900,
    "peak_sensitivity" = 0.2,
    "max_peak_flow_date" = 325,
    "min_summer_flow_percent" = 0.125,
    "min_flow_rate" = 1
  )
)

class_params = list(
  "SM" = general_parameters, # snowmelt
  "HSR" = general_parameters, # high volume snowmelt and rain
  "LSR" = general_parameters, # low volume snowmelt and rain
  "WS" = general_parameters, # winter storms
  "PGR" = general_parameters,  # perrenial groundwater and rain
  "GW" = general_parameters, # groundwater
  "FER" = general_parameters, # flashy ephemeral rain
  "RGW" = general_parameters, # rain and seasonal groundwater
  "HLP" = general_parameters # high elevation low precipitation
)

# Winter Storms changes
class_params$WS$spring_params$max_peak_flow_date <- 255
class_params$WS$spring_params$peak_filter_percentage <- 0.1
class_params$WS$spring_params$window_sigma <- 2.5
class_params$WS$spring_params$min_percentage_of_max_flow <- 0.05
class_params$WS$summer_params$sigma <- 4
class_params$WS$summer_params$sensitivity <- 1100
class_params$WS$summer_params$peak_sensitivity <- 0.1

# Perennial Groundwater and Rain changes
class_params$PGR$spring_params$max_peak_flow_date <- 255
class_params$PGR$spring_params$peak_filter_percentage <- 0.12
class_params$PGR$spring_params$window_sigma <- 2.5
class_params$PGR$spring_params$min_percentage_of_max_flow <- 0.12
class_params$PGR$summer_params$sigma <- 4
class_params$PGR$summer_params$sensitivity <- 1100
class_params$PGR$summer_params$peak_sensitivity <- 0.1

# Flashy Ephemeral Rain changes
class_params$FER$spring_params$max_peak_flow_date <- 255
class_params$FER$spring_params$peak_filter_percentage <- 0.05
class_params$FER$spring_params$window_sigma <- 2
class_params$FER$spring_params$min_percentage_of_max_flow <- 0.05
class_params$FER$summer_params$sigma <- 4
class_params$FER$summer_params$sensitivity <- 1100
class_params$FER$summer_params$peak_sensitivity <- 0.1

# Rain and Seasonal Groundwater changes
class_params$RGW$spring_params$max_peak_flow_date <- 255
class_params$RGW$spring_params$peak_filter_percentage <- 0.15
class_params$RGW$spring_params$window_sigma <- 2.5
class_params$RGW$spring_params$min_percentage_of_max_flow <- 0.15
class_params$RGW$summer_params$sigma <- 4
class_params$RGW$summer_params$sensitivity <- 1100
class_params$RGW$summer_params$peak_sensitivity <- 0.1


get_stream_class_code_for_comid <- function(comid){
  stream_class_data <- get_dataset("stream_class_data")
  return(as.character(stream_class_data[stream_class_data$COMID == comid, ]$CLASS_CODE))
}

#' Get the parameters sent to the FFC for a stream segment
#'
#' Given a COMID, looks up the hydrogeomorphic stream classification, then uses that to find the default parameters that
#' should be sent to the FFC online for that stream class. Returns a nested list of parameters to send to the FFC.
#'
#' @param comid An NHD stream segment COMID
#'
#' @export
get_ffc_parameters_for_comid <- function(comid){
  stream_class_code <- get_stream_class_code_for_comid(comid)
  if(length(stream_class_code) == 0){  # the comid wasn't found
    return(general_parameters)  # so return the general parameters
  }

  return(class_params[[stream_class_code]])  # otherwise, return the class-specific parameters (which could be general, or not)
}
