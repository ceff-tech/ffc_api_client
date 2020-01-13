
single_metric_alteration <- function(metric, percentiles, predictions, ffc_values, low_bound_percentile, high_bound_percentile, prediction_proportion, days_in_water_year){
  if(missing(low_bound)){
    low_bound_percentile = "p10"
  }
  if(missing(high_bound)){
    high_bound_percentile = "p90"
  }
  if(missing(prediction_proportion)){
    prediction_proportion = 0.2
  }
  if(missing(days_in_water_year)){
    days_in_water_year <- 365
  }

  low_bound <- predictions[[low_bound_percentile]]
  high_bound <- predictions[[high_bound_percentile]]

  # we assess whether the values are altered here because it's different for timing than anything else
  # -1 = low/early
  # 0 = in range
  # 1 = high/late
  if(grepl("_Tim", metric)){
    # determine if each year's observed values are early, late, or within range
    assessed_observations = mapply(early_or_late, ffc_values, MoreArgs=list("early_value" = low_bound, "late_value" = high_bound, "days_in_water_year" = days_in_water_year))
  }else{

    ffc_no_NAs <- ffc_values[!is.na(ffc_values)]
    ffc_above_low_bound <- ffc_no_NAs[ffc_no_NAs > low_bound]
    ffc_i80r <- ffc_above_low_bound[ffc_above_low_bound < high_bound]

    assessed_observations <- ffc_no_NAs
    assessed_observations[assessed_observations < low_bound] <- -1
    assessed_observations[assessed_observations >= low_bound && assessed_observations <= high_bound] <- 0
    assessed_observations[assessed_observations > high_bound] <- 1
  }
  return(determine_status(percentiles, low_bound, high_bound, assessed_observations, metric, days_in_water_year, prediction_proportion))
}

determine_status <- function(percentiles, low_bound, high_bound, assessed_observations, metric, days_in_water_year, prediction_proportion){
  status_code = 3
  status = "indeterminate"
  alteration_type = "unknown"
  # Aiming at Type 1 unaltered here - median in bounds AND 50% of observations in bounds
  if( (!grepl("_Tim", metric) && percentiles$p50 > low_bound && percentiles$p50 < high_bound ) ||
      (grepl("_Tim", metric) && early_or_late(percentiles$p50, low_bound, high_bound, days_in_water_year) == 0)){
    # see if count of values in bounds > 50% of total non-NA values

    observation_counts <- table(assessed_observations)
    unaltered_observations <- observation_counts[names(observation_counts) == 0]
    if((unaltered_observations / length(assessed_observations)) >= 0.5){
      status_code = 1
      status = "likely unaltered"
      alteration_type = "none found"
    }
  }else{ # we're not unaltered, but we're not yet sure we're altered - median is off, but let's check how far
    if(grepl("_Tim", metric)){
      timing_alteration_value <- early_or_late(percentiles$p50, low_bound, high_bound, days_in_water_year)
      if(timing_alteration_value == -1){
        alteration_type <- "early"
      }else{
        alteration_type <- "late"
      }

      window_size <- high_bound - low_bound
      if(!((1 + 2*prediction_proportion) * window_size >= days_in_water_year)){  # if we expand the window and it's bigger than the days in the water year, we're indeterminate
        # in here, the expanded window would have fewer days than the water year, but which days, who knows!
        high_bound_expanded <- (high_bound + predicted_proportion * window_size) %% days_in_water_year
        low_bound_expanded <- (low_bound - predicted_propotion * window_size) %% days_in_water_year
      }
      if (high_bound_expanded > low_bound_expanded){
        # Since we already checked that expansion wasn't going to make the window bigger than a year, then if high bound
        # is greater than the low bound, we know we don't cross water years. Values b/t low and high are indeterminate, outside
        # of that range, likely altered
        if(percentiles$p50 > high_bound_expanded || perecentiles$p50 < low_bound_expanded){
          status_code = 2
          status = "likely altered"
        }
      }else {
        # in here, high_bound_expanded < low_bound_expanded - aka, we crossed the water year boundary on one end. That means
        # that the values *between* them are likely altered, and outside them are indeterminate

        if(percentiles$p50 < high_bound_expanded || percentiles$p50 > low_bound_expanded){
          status_code = 2
          status = "likely_altered"
        }
      }

      # TODO: Need to assess if it's in the timing alteration prediction interval - that's less than straightforward to construct
      # again because of how timing wraps around.

    } else if (percentiles$p50 < low_bound){
      alteration_type = "low"
      if (percentiles$p50 < (low_bound - (low_bound * prediction_proportion))){
        status_code = 2
        status = "likely altered"
      }
    } else {
      alteration_type = "high"
      if (percentiles$p50 > (high_bound + (high_bound * prediction_proportion))){
        status_code = 2
        status = "likely altered"
      }
    }
  }

  return(list("status_code" = status_code, "status" = status, "alteration_type" = alteration_type))
}


#'
#'
#' So here's a pain in the rear - for timing metrics, none of them have percentiles that cross water years
#' (which seems kind of suspicious to me, but whatever), so the upper bound will never be earlier
#' in the water year than the lower bound - that makes things a bit easier. BUT, for alteration,
#' we have plenty of timing metrics that are predicted to be very early in the water year. If the actual
#' value is early enough that it's in the previous water year (looking at you fall flushing flow), then
#' we don't want to mark it as being *late* when it's actually early! So, we need to have some rules for early
#' and late for timing. Planning to determine the range of values that aren't in the inter-80th percentile range
#' and then find the day of the water year that's in the middle. Timings earlier than that are late, timings after that
#' are early.
timing_alteration <- function(median_value, low_bound, upper_bound, days_in_water_year){
  if(missing(days_in_water_year)){
    days_in_water_year <- 365
  }
}


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
#' based on the modeled early_value, modeled late_value, and the actual value. It returns within range (0)
#' if the value is between early_value and late_value. If not, it splits the distance between late_value and
#' early_value in two, rolling over at the end of the calendar year, and assesses if the value is closer to
#' the late_value (then returns late (1)), or the early value (then returns early (-1))
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

