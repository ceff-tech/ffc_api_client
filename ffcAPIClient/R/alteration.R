LIKELY_ALTERED_STATUS_CODE = -1
INDETERMINATE_STATUS_CODE = 0
LIKELY_UNALTERED_STATUS_CODE = 1

#' Assess hydrologic alteration by flow metric
#'
#' Returns a data frame with an alteration status assessment for every flow metric.
#'
#' Generates an alteration status assessment for every flow metric based on the rules developed under CEFF for flow
#' alteration. This function pairs well with the boxplots for visualizing alteration, but only this function assesses
#' the data under the rules. Returns a data frame with columns "metric" , "status_code",
#' "status", "alteration_type", "median_in_iqr", and "comid".
#'
#' The \code{comid} will be the same for all rows, and will match what you provide
#' as an input, but allows for merging of these results into larger tables.
#'
#' \code{status_code} will be -1 (likely altered), 0 (indeterminate), 1 (likely unaltered), or NA (insufficient data to determine).
#' \code{status} will be a text description of the status code (-1=likely_altered, 0=indeterminate, 1=likely_unaltered, NA=Not_enough_data).
#' \code{alteration_type} will tell you the direction of potential alteration for likely altered and indeterminate metrics - the direction
#' of alteration is determined by comparing the median value to the 25th and 7th percentiles of the predicted metrics. It will
#' provide "low" or "high" values for most metrics and "early" or "late" values for timing metrics. For likely_unaltered metrics,
#' it will provide "none_found" and for metrics with insufficient data, it will provide "undeterminable.". Also includes a boolean field
# \code{median_in_iqr} indicating whether the median is in the interquartile range.
#
#'
#' @param percentiles dataframe of calculated FFC results percentiles, including the metric column and columns for p10,p25,p50,p75, and p90
#' @param predictions dataframe of predicted flow metrics, as returned from \code{get_predicted_flow_metrics}.
#' @param ffc_values dataframe of the raw results from the online FFC, as returned by \code{evaluate_gage_alteration} or \code{get_results_as_df}
#' @param comid integer comid of the stream segment the previous parameters are for
#' @param annual boolean indicating whether to run a year over year analysis. If \code{TRUE}, then the parameter \code{percentiles}
#'               changes and should be a data frame with only two columns - the first is still \code{metric}, but the second is just
#'               \code{value} representing the current year's value for the metric. \code{predictions} should then still have fields
#'               for the \code{metric}, \code{p25}, and \code{p75}, where \code{p25} and \code{p75} represent the lower and upper
#'               bounds for comparison, regardless of if they're calculated percentiles, or another set of bounds. When run in an
#'               annual mode, it assesses alteration similarly to the description above, and with the same result structure, but
#'               provides likely_unaltered results when \code{value} is within the \code{p25} and \code{p75} values, and provides
#'               likely_altered otherwise without additional checks described in the CEFF guidance document, appendix F.
#' @export
assess_alteration <- function(percentiles, predictions, ffc_values, comid, annual){
  if(missing(annual)){
    annual <- FALSE
  }

  # reduce the percentiles we're considering to the ones we have matching predictions for - can't assess the others
  percentiles <- percentiles[percentiles$metric %in% as.character(predictions$metric), ]
  # assess alteration on a metric by metric basis, bind back to data frame, and attach a comid

  alteration_list <- apply(percentiles, MARGIN = 1, FUN = single_metric_alteration, predictions, ffc_values, annual)
  alteration_df <- do.call("rbind", alteration_list)
  alteration_df$comid <- comid
  return(alteration_df)
}


# Assess the alteration of a single flow metric
#
# Given a metric's calculated percentiles, raw FFC output values, and predictions, returns a row of information indicating
# whether or not that metric is likely altered, indeterminate, or likely unaltered. Includes fields with a text status,
# an integer code (1=likely unaltered, 0=indeterminate, -1=likely altered), as well as for which direction alteration is (or may be)
# in if it's indeterminate or likely altered (values are low/high or early/late for timing metrics). Also includes a boolean field
# \code{median_in_iqr} indicating whether the median is in the interquartile range.
#
# @param percentiles data frame row - should have a named value "p50" that can be accessed, at the very least and a column
#                     metric with the flow metric in it. These are calculated percentile values from the FFC.
# @param predictions data frame (or other named field item) the predicted flow metric values for the segment and metric
# @param ffc_values vector of raw observed metric values (FFC output) for this metric
# @param days_in_water_year numeric of how many days in the water year (defaults to 365, but could be 366).
single_metric_alteration <- function(percentiles, predictions, ffc_values, days_in_water_year, annual){
  if(missing(days_in_water_year)){
    days_in_water_year <- 365
  }
  if(missing(annual)){
    annual <- FALSE
  }

  metric <- percentiles[["metric"]]
  predictions <- as.data.frame(predictions)
  predictions <- predictions[predictions$metric == metric, ]
  ffc_values <- dplyr::select(ffc_values, metric)

  if(!annual){
    assessed_observations = assess_observations(ffc_values, predictions)

    if (is.null(assessed_observations)) {  # assess_observations returns NULL if there's not enough data
      return(data.frame("metric" = metric, "status_code" = NA, "status" = "Not_enough_data", "alteration_type" = "undeterminable", stringsAsFactors = FALSE))
    }
    median = as.double(percentiles[["p50"]])
  }else{
    assessed_observations <- NULL  # we won't need it in an annual analysis
    median = as.double(percentiles[["value"]])
  }

  return(determine_status(median = median,
                          predictions = predictions,
                          assessed_observations = assessed_observations,
                          metric = metric,
                          days_in_water_year = days_in_water_year,
                          annual = annual))
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


# Calculate the alteration status of a flow metric
#
# This method returns an alteration status record for a specific flow metric, but requires the calculated FFC percentiles,
# a lower and upper bound, and a set of observations that have already been assessed for whether they're within that lower
# or upper bound so that they are -1 for low/early, 0 for within range, and 1 for high/late.
#
# @param median The calculated median value from the observed data
# @param predictions The predicted metric values for this specific metric - should have p10, p25, p50, p75, p90 values
# @param assessed_observations vector of raw observed metric values (FFC output) that has already been assessed for whether it is in range
#                     so that records that are low/early are -1, records that are in range are 0, and records that are high/late are 1
# @param metric character name of the metric - case sensitive. Currently only used for timing metrics, which must have "_Tim" in the name
# @param days_in_water_year numeric of how many days in the water year (typically 365, but could be 366).
determine_status <- function(median, predictions, assessed_observations, metric, days_in_water_year, annual){
  if(missing(annual)){
    annual <- FALSE
  }

  # set some defaults - we'll now prove it's not this, or otherwise return these values
  status_code <- INDETERMINATE_STATUS_CODE
  status <- "indeterminate"
  alteration_type <- "unknown"

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

  # Ted wants to know if values are in the IQR still, so we'll include that separately, even if there's no logic for how it impacts alteration assessment
  if(median_in_range_strict(median, predictions[["p25"]], predictions[["p75"]])) {
    median_in_iqr = TRUE
  }else{
    median_in_iqr = FALSE
  }

  if (median >= predictions[["p10"]] && median <= predictions[["p90"]]){
    # for regular metrics, if we're in here, then we have a chance at being unaltered if
    # 50% of observations are in range
    if(annual || observations_in_range(assessed_observations = assessed_observations)){  # if the annual flag is passed, skip the observations check
      status_code = LIKELY_UNALTERED_STATUS_CODE
      status = "likely_unaltered"
      alteration_type = "none_found"
    } # otherwise if we're in this block we leave it alone because it's indeterminate
  } else { # otherwise, we're altered
    status_code = LIKELY_ALTERED_STATUS_CODE
    status = "likely_altered"
  }

  return(data.frame("metric" = metric, "status_code" = status_code, "status" = status, "alteration_type" = alteration_type, "median_in_iqr" = median_in_iqr, stringsAsFactors = FALSE))
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

