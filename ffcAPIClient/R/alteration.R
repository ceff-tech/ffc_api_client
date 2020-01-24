LIKELY_ALTERED_STATUS_CODE = -1
INDETERMINATE_STATUS_CODE = 0
LIKELY_UNALTERED_STATUS_CODE = 1

#' Assess hydrologic alteration by flow metric
#'
#' Returns a data frame with an alteration status assessment for every flow metric.
#'
#' Generates an alteration status assessment for every flow metric based on the rules developed under CEFF for flow
#' alteration. This function pairs well with the boxplots for visualizing alteration, but only this function assesses
#' the data under the rules. Returns a data frame with columns "Metric" (note capitalization, consistent with other
#' data frames with a flow metric, even if not consistent with otherwise lowercase names here, sorry), "status_code",
#' "status", "alteration_type", and "comid".
#'
#' The \code{comid} will be the same for all rows, and will match what you provide
#' as an input, but allows for merging of these results into larger tables.
#'
#' \code{status_code} will be -1 (likely altered), 0 (indeterminate), 1 (likely unaltered), or NA (insufficient data to determine).
#' \code{status} will be a text description of the status code (-1=likely_altered, 0=indeterminate, 1=likely_unaltered, NA=Not_enough_data).
#' \code{alteration_type} will tell you the direction of potential alteration for likely altered and indeterminate metrics. It will
#' provide "low" or "high" values for most metrics and "early" or "late" values for timing metrics. For likely_unaltered metrics,
#' it will provide "none_found" and for metrics with insufficient data, it will provide "undeterminable.".
#'
#' @param percentiles dataframe of calculated FFC results percentiles, including the Metric column and columns for p10,p25,p50,p75, and p90
#' @param predictions dataframe of predicted flow metrics, as returned from \ref{\code{get_predicted_flow_metrics}}.
#' @param ffc_values dataframe of the raw results from the online FFC, as returned by \ref{\code{evaluate_gage_alteration}} or \ref{\code{get_results_as_df}}
#' @param comid integer comid of the stream segment the previous parameters are for
#'
#' @export
assess_alteration <- function(percentiles, predictions, ffc_values, comid){
  percentiles <- percentiles[percentiles$Metric %in% as.character(predictions$Metric), ]
  alteration_list <- apply(percentiles, MARGIN = 1, FUN = single_metric_alteration, predictions, ffc_values)
  alteration_df <- do.call("rbind", alteration_list)
  alteration_df$comid <- comid
  return(alteration_df)
}


#' Assess the alteration of a single flow metric
#'
#' Given a metric's calculated percentiles, raw FFC output values, and predictions, returns a row of information indicating
#' whether or not that metric is likely altered, indeterminate, or likely unaltered. Includes fields with a text status,
#' an integer code (1=likely unaltered, 2=indeterminate, 3=likely altered), as well as for which direction alteration is (or may be)
#' in if it's indeterminate or likely altered (values are low/high or early/late for timing metrics)
#'
#' @param percentiles data frame row - should have a named value "p50" that can be accessed, at the very least and a column
#'                     Metric with the flow metric in it. These are calculated percentile values from the FFC.
#' @param predictions data frame (or other named field item) the predicted flow metric values for the segment and metric
#' @param ffc_values vector of raw observed metric values (FFC output) for this metric
#' @param days_in_water_year numeric of how many days in the water year (defaults to 365, but could be 366).
#' @export
single_metric_alteration <- function(percentiles, predictions, ffc_values, days_in_water_year, annual){
  if(missing(days_in_water_year)){
    days_in_water_year <- 365
  }
  if(missing(annual)){
    annual <- FALSE
  }
  if(missing(percentiles) && annual == FALSE){
    stop("Missing percentiles data, but not running an annual analysis. Parameter 'annual' to single_metric_alteration must
          be TRUE to run an annual analysis")
  }
  metric <- percentiles[["Metric"]]
  predictions <- as.data.frame(predictions)
  predictions <- predictions[predictions$Metric == metric, ]
  ffc_values <- dplyr::select(ffc_values, metric)

  # we assess whether the values are altered here because it's different for timing than anything else
  # -1 = low/early
  # 0 = in range
  # 1 = high/late
  #if (grepl("_Tim", metric)) {
  #  low_bound <- predictions$p25
  #  high_bound <- predictions$p75
  #  # determine if each year's observed values are early, late, or within range
  #  assessed_observations = mapply(early_or_late_simple, ffc_values, MoreArgs = list("early_value" = low_bound, "late_value" = high_bound, "days_in_water_year" = days_in_water_year))
  #}else{
  assessed_observations = assess_observations(ffc_values, predictions)
  #}

  if (is.null(assessed_observations)) {
    return(data.frame("metric" = metric, "status_code" = NA, "status" = "Not_enough_data", "alteration_type" = "undeterminable", stringsAsFactors = FALSE))
  }

  return(determine_status(median = as.double(percentiles[["p50"]]),
                          predictions = predictions,
                          assessed_observations = assessed_observations,
                          metric = metric,
                          days_in_water_year = days_in_water_year))
}

assess_observations <- function(ffc_values, predictions){
  ffc_no_NAs <- as.numeric(ffc_values[!is.na(ffc_values)])
  if(length(ffc_no_NAs) == 0){
    return(NULL)
  }
  low_bound <- predictions$p10
  high_bound <- predictions$p90

  assessed_observations <- as.vector(ffc_no_NAs)
  # assign impossible values first so we don't overlap any real values
  assessed_observations[assessed_observations < low_bound] <- -1
  assessed_observations[assessed_observations > high_bound] <- -3
  assessed_observations[assessed_observations > 0] <- -2

  # now assign the real values we want
  assessed_observations[assessed_observations == -3] <- 1
  assessed_observations[assessed_observations == -2] <- 0
  return(assessed_observations)
}


#' Calculate the alteration status of a flow metric
#'
#' This method returns an alteration status record for a specific flow metric, but requires the calculated FFC percentiles,
#' a lower and upper bound, and a set of observations that have already been assessed for whether they're within that lower
#' or upper bound so that they are -1 for low/early, 0 for within range, and 1 for high/late. They need to already be assessed
#' because some metrics (*ahem* timing) need their own ways to assess low/high, or early/late
#'
#' @param median The calculated median value from the observed data
#' @param predictions The predicted metric values for this specific metric - should have p10, p25, p50, p75, p90 values
#' @param assessed_observations vector of raw observed metric values (FFC output) that has already been assessed for whether it is in range
#'                     so that records that are low/early are -1, records that are in range are 0, and records that are high/late are 1
#' @param metric character name of the metric - case sensitive. Currently only used for timing metrics, which must have "_Tim" in the name
#' @param days_in_water_year numeric of how many days in the water year (typically 365, but could be 366).
determine_status <- function(median, predictions, assessed_observations, metric, days_in_water_year){

  # set some defaults - we'll now prove it's not this, or otherwise return these values
  status_code <- INDETERMINATE_STATUS_CODE
  status <- "indeterminate"
  alteration_type <- "unknown"

  # Aiming at Type 1 unaltered here - median in bounds
  if (median_in_range_strict(median, predictions[["p25"]], predictions[["p75"]])) {
    status_code = LIKELY_UNALTERED_STATUS_CODE
    status = "likely_unaltered"
    alteration_type = "none_found"
  } else {  # we're not unaltered, but we're not yet sure we're altered - median is off, but let's check how far
    # set the direction here
    if (median < predictions[["p25"]]){
      if (grepl("_Tim", metric)){
        alteration_type <- "early"
      } else {
        alteration_type <- "low"
      }
    }
    if(median > predictions[["p75"]]){
      if(grepl("_Tim", metric)){
        alteration_type <- "late"
      } else {
      alteration_type <- "high"
      }
    }
    #  timing_alteration_value <- early_or_late_simple(median, predictions$p25, predictions$p75, days_in_water_year)
    #  if(timing_alteration_value == -1){
    #    alteration_type <- "early"
    #  }else{  # it shouldn't come back 0 here because we're outside the timing window already, so safe to assume late now.
    #    alteration_type <- "late"
    #  }
    # we used to have separate logic for timing because it could wrap around. But now we don't because apparently all the
    # other FFC/predictions code assumes nothing except duration metrics crosses water years. Sarah Yarnell says that early/
    # late are also just a function of earlier in the water year or later in the water year. Something early won't ever
    # cross the water year boundary to appear late (which lots of the commented out code handles)
    #if(grepl("_Tim", metric)){
    #  timing_alteration_value <- early_or_late_simple(median, predictions$p25, predictions$p75, days_in_water_year)
    #  if(timing_alteration_value == -1){
    #    alteration_type <- "early"
    #  }else{  # it shouldn't come back 0 here because we're outside the timing window already, so safe to assume late now.
    #    alteration_type <- "late"
    #  }

    #  window_size <- predictions$p75 - predictions$p25
    #  if(!((1 + 2*prediction_proportion) * window_size >= days_in_water_year)){  # if we expand the window and it's bigger than the days in the water year, we're indeterminate
    #    # in here, the expanded window would have fewer days than the water year, but which days, who knows!
    #    high_bound_expanded <- (predictions$p75 + predicted_proportion * window_size) %% days_in_water_year
    #    low_bound_expanded <- (predictions$p25 - predicted_proportion * window_size) %% days_in_water_year
    #  }
    #  if (high_bound_expanded > low_bound_expanded){
    #    # Since we already checked that expansion wasn't going to make the window bigger than a year, then if high bound
    #    # is greater than the low bound, we know we don't cross water years. Values b/t low and high are indeterminate, outside
    #    # of that range, likely altered
    #    if(median > high_bound_expanded || median < low_bound_expanded){
    #      status_code <- LIKELY_ALTERED_STATUS_CODE
    #      status <- "likely altered"
    #    }
    #  }else {
    #    # in here, high_bound_expanded < low_bound_expanded - aka, we crossed the water year boundary on one end. That means
    #    # that the values *between* them are likely altered, and outside them are indeterminate
    #
    #    if(median < high_bound_expanded || median > low_bound_expanded){
    #      status_code <- LIKELY_ALTERED_STATUS_CODE
    #      status <- "likely_altered"
    #    }
    #  }
    #}
    if (median >= predictions[["p10"]] && median <= predictions[["p90"]]){
      # for regular metrics, if we're in here, then we have a chance at being unaltered if
      # 50% of observations are in range
      if(observations_in_range(assessed_observations = assessed_observations)){
        status_code = LIKELY_UNALTERED_STATUS_CODE
        status = "likely_unaltered"
        alteration_type = "none_found"
      } # otherwise we leave it alone because it's indeterminate
    } else { # otherwise, we're altered
      status_code = LIKELY_ALTERED_STATUS_CODE
      status = "likely_altered"
    }
  }

  return(data.frame("Metric" = metric, "status_code" = status_code, "status" = status, "alteration_type" = alteration_type, stringsAsFactors = FALSE))
}



observations_in_range <- function(assessed_observations){
  observation_counts <- table(assessed_observations)

  if(!(0 %in% names(observation_counts))){  # if we don't have *any* zeros, the code below will break. return that it's out of range
    return(FALSE)
  }

  # now check the proportion of zeros provided
  unaltered_observations <- observation_counts[names(observation_counts) == 0]
  if((unaltered_observations / length(assessed_observations)) >= 0.5){
    return(TRUE)
  }
  return(FALSE)
}


median_in_range_strict <- function(value, low_bound, high_bound){
  if (value >= low_bound && value <= high_bound) {
    return(TRUE)
  }
  return(FALSE)
}


# Returns the midpoint between two values wrapping around the two values. First value should be bigger,
# Second value should be smaller. If reversed, it just does a standard midpoint between the two.
# Useful for finding the midpoint between the end of something and the start again in a year.
modulo_midpoint <- function(first_value, second_value, modulo_value){
  if(first_value < second_value){
    return((second_value - first_value) %/% 2)  # force integer division
  }
  range_size <- modulo_value - first_value + second_value
  raw_middistance <- range_size %/% 2  # do an integer division
  raw_midpoint <- first_value + raw_middistance
  midpoint <- raw_midpoint %% modulo_value  # get it to be a timing value again
  if(midpoint == 0){
    midpoint <- 1  # push it to day 1, there is no day 0
  }

  return(midpoint)
}


#' Determine if timing metrics are early, late, or in range
#'
#' Properly rolls over the calendar at 365 days, but can tell you if a metric is early, late, or "within range"
#' based on the modeled early_value, modeled late_value, and the actual value.
#'
#' It returns within range (0)
#' if the value is between early_value and late_value. If not, it splits the distance between late_value and
#' early_value in two, rolling over at the end of the calendar year, and assesses if the value is closer to
#' the late_value (then returns late (1)), or the early value (then returns early (-1)).
#'
#' This function is currently not used in the package - instead, a simpler evaluation that does not roll
#' over the calendar year is used.
#'
#' @export
early_or_late <- function(value, early_value, late_value, days_in_water_year){
  if(missing(days_in_water_year)){
    days_in_water_year <- 365
  }

  if(value > early_value && value < late_value){
    return(0)
  }

  midpoint <- modulo_midpoint(first_value = late_value, second_value = early_value, modulo_value = days_in_water_year)
  if(midpoint < early_value){  # it's the midpoint is in the first part of the water year
    if(value > midpoint && value < early_value){  # and the value is between the beginning of the water year and now
      return(-1)  # then it's early
    }else{
      return(1)  # if it's not early, it's late!
    }
  }else{  # the midpoint is after the late value in the water year
    if(value < midpoint && value > late_value){
      return(1)
    }else{
      return(-1)
    }
  }
}

# Similar to early or late, but just does a simple check - if the value is less than
# the early value in raw numbers, it's early. If it's bigger than the late value in
# raw numbers, it's late. Assumes that nothing crosses the water year in timing.
early_or_late_simple <- function(value, early_value, late_value, days_in_water_year){
  if(missing(days_in_water_year)){
    days_in_water_year <- 365
  }

  if(value >= early_value && value <= late_value){
    return(0)
  }

  if(value < early_value){
    return(-1)
  }

  return(1)  # if it's not in the ranges above, we're late

}

