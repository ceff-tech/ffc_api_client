#' Filter Timeseries data
#'
#' When we send data to the FFC, it needs to meet a specific set of requirements.
#' The code in this file aims to make sure input data, whether gaged or
#' a manual timeseries, follows those requirements. Namely:
#'
#' 1. We should only send complete water years - partial water years at the beginning or end
#' have an outsize influence on the calculations. This rule will actually be handled just by
#' adhering to the next two rules.
#'
#' 2. Along the same lines, we shouldn't allow any large gaps. When we find a gap
#' of *2 or more days*, then we should drop the entire water year.
#'
#' 3. We should only allow 7 total missing days, which we will fill either with
#' values from the previous day, or a linear interpolation (maybe with a flag?)
#' before sending to the FFC.
#'
#' The functions in this file should accept a timeseries data frame, and assess/filter
#' it according to these rules, then return a new timeseries to the caller. The timeseries
#' should already be *daily* data.
#'
filter_timeseries <- function(timeseries,
                              date_field,
                              flow_field,
                              date_format_string,
                              max_missing_days = 7,
                              max_consecutive_missing_days = 1,
                              fill_gaps = "no"){  # fill_gaps can be "no" to disable,
                                                  # "linear" for linear interpolation,
                                                  # or "previous" to use the previous day

  # First, let's get rid of any NA or NULL values in the flow field - the rest of the logic is looking for
  # cases where a date or observation is entirely missing, so we should remove records that don't have
  # flow data up front.
  timeseries <- timeseries[!is.na(timeseries[[flow_field]]), ]

  # we need the data to be in order so we can check for gaps, but we can't guarantee
  # the current date field is in a sortable format - add a posix time field so we can
  # sort it
  timeseries$posix_time <- strptime(timeseries[[date_field]], format=date_format_string, tz="US/Pacific")

  # attach year/month/day/water year fields
  timeseries <- attach_water_year_data(timeseries, date_field = "posix_time")

  # now sort it - will sort ascending by default (great!)
  timeseries_sorted <- timeseries[order(timeseries$posix_time), ]

  # now get some metadata - we want to know the count of entries for each year - we can quickly remove any
  # year with n_days_in_year - max_missing_days values, and we can quickly keep any year with 365 or more
  # entries (it could be a leap year with a single missing day, but we'll either leave that as is or try
  # to fill it later). It's the ones in between that we need to check to see if they have gaps larger
  # than max_consecutive_missing_days (in which case we'll drop them), otherwise we'll potentially
  # attempt to fill gaps
  year_counts <- as.data.frame(table(timeseries_sorted$water_year), stringsAsFactors = FALSE)
  year_counts$year <- as.numeric(year_counts$Var1)

  # for now, we'll just pretend leap years don't exist (in a way that's safe for leap year breakages still)
  # figure out the minimum
  incomplete_year_length <- 365 - max_missing_days
  keep_years <- year_counts[year_counts$Freq > incomplete_year_length, "year"]  # get the list of years that have enough data
  complete_years <- timeseries_sorted[timeseries_sorted$water_year %in% keep_years,]  # filter the data to only the complete years

  # initialize an empty vector - we'll append years that fail the checks here, then we'll remove them
  exclude_years <- c()
  # might be able to vectorize this, but it's fine as a loop - short and simple
  # now check each water year for gaps larger than max_consecutive_missing_days
  for(year in min(complete_years$water_year):max(complete_years$water_year)){
    # so, we might end up with a gap of more than 1 day at the end of a single water year and the
    # beginning of another, but that's OK in this context since the years will be processed separately
    year_data <- complete_years[complete_years$water_year == year, ]  # get the year data
    hour_differences <- diff(year_data$posix_time)  # get the number of hours between each observation and the next

    # if any time difference in observations is greater than the number of missing days + 12 hours (12 to make sure we're in between days)
    if(any(hour_differences > ((max_consecutive_missing_days * 24) + 12))){
      append(exclude_years, year)
    }
  }

  # these years are complete, but may have gaps
  complete_years <- complete_years[!(complete_years$water_year %in% exclude_years), ]

  if(fill_gaps != "no"){
    # if we're supposed to fill any remaining gaps
  }

  return(complete_years)
}


#' Add calendar_year/calendar_month/calendar_day/water_year fields
#'
#' Attaches fields for the year, month, day and water year to a data frame with a POSIX time field
#'
attach_water_year_data <- function(timeseries, date_field = "posix_time"){
  timeseries$calendar_year <- as.numeric(strftime(timeseries[, date_field], "%Y"))
  timeseries$calendar_month <- as.numeric(strftime(timeseries[, date_field], "%m"))
  timeseries$calendar_day <- as.numeric(strftime(timeseries[, date_field], "%d"))

  # add the water year
  timeseries[timeseries$calendar_month < 10, "water_year"] <- as.numeric(timeseries[timeseries$calendar_month < 10, "calendar_year"])
  timeseries[timeseries$calendar_month > 9, "water_year"] <- as.numeric(timeseries[timeseries$calendar_month > 9, "calendar_year"] + 1)

  return(timeseries)
}
