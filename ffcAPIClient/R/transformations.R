
# returns the dimensionless reference hydrograph results as a data frame

#' @export
get_drh <- function(results){
  # Pulls the DRH data for a named result and transforms it into a data frame that can be used for plotting and analysis
  drh <- t(do.call(rbind.data.frame, results$DRH))  # rowbind, but transpose
  rownames(drh) <- seq(1,366)  # reset the rownames to days
  drh_data <- data.frame(drh)
  drh_data <- dplyr::mutate(drh_data, days = seq(1:nrow(drh_data)))
  return(drh_data)  # convert to data frame and return
}


#' Plots the Dimensionless Reference Hydrograph
#'
#' Given a set of results data from get_ffc_results_for_df or get_ffc_results_for_usgs_gage,
#' processes the DRH data and returns a plot object.
#'
#' Credit to Ryan Peek for the code in this function.
#'
#' @param results list.
#' @param output_path, default NULL. Optional. When set, saves the DRH plot to the output
#'   file path provided.
#'
#' @export
plot_drh <- function(results, output_path){
  if(missing(output_path)){
    output_path = NULL
  }

  drh_data <- get_drh(results)

  drh_plot <- ggplot2::ggplot() +
    ggplot2::geom_ribbon(data=drh_data, ggplot2::aes(x=days, ymin=ten, ymax=ninty), fill="skyblue", alpha=0.3) +
    ggplot2::geom_ribbon(data=drh_data, ggplot2::aes(x=days, ymin=twenty_five, ymax=seventy_five), fill="slateblue", alpha=0.3) +
    ggplot2::geom_line(data=drh_data, ggplot2::aes(x=days, y=fifty), color="black", lwd=1.2) +
    ggplot2::theme_classic() +
    ggplot2::labs(title="Dimensionless Hydrograph", x="Water Year Day",
         y="Daily median flow / Avg annual flow",
         caption="Daily median flow with 10/90 percentiles (light blue), and 25/75 percentiles in purple")

  if(!is.null(output_path)){
    ggplot2::ggsave(filename = output_path, width = 7, height = 5, units = "in", dpi=300)
  }

  return(drh_plot)
}


#' Convert FFC results list to data frame with metric names
#'
#' More documentation forthcoming
#'
#' @export
get_results_as_df <- function (results){
  main_items <- c("summer", "fall", "spring", "fallWinter")
  winter_timings <- c("timings", "durations", "magnitudes", "frequencys")

  results_main <- mapply(convert_season_to_df, main_items, MoreArgs=list(all_data=results, rename_metrics=rename_by_metric, yearRanges=results$yearRanges))
  results_main_df <- Reduce(merge_list, results_main)

  results_winter <- mapply(convert_season_to_df, winter_timings, MoreArgs=list(all_data=results$winter, rename_metrics=rename_by_metric$winter, yearRanges=results$yearRanges))
  results_winter_df <- Reduce(merge_list, results_winter)

  return(merge(results_main_df, results_winter_df, by="Year"))
}


plot_comparison_boxes <- function(ffc_results_df, predictions_df){ #, ){
  groups <- c("DS_", "FA_", "Wet_", "SP_", "Peak_Tim", "Peak_Dur", "Peak_Fre", "Peak_\\d")

  ffc_results_df["result_type"] <- "observed"
  predictions_df["result_type"] <- "predicted"

  drop_cols <- c("COMID", "source")
  predictions_df <- dplyr::select(predictions_df, -dplyr::one_of(drop_cols))

  full_df <- rbind(ffc_results_df, predictions_df)

  full_df <- dplyr::filter(full_df, !grepl("_Julian", Metric))
  full_df <- dplyr::filter(full_df, !grepl("X__", Metric))

  for(group in groups){
    metrics <- dplyr::filter(full_df, grepl(group, Metric))
    plt <- ggplot2::ggplot(metrics, ggplot2::aes(x=Metric, fill=result_type))  +
      ggplot2::geom_boxplot(
        ggplot2::aes(ymin = p10, lower = p25, middle = p50, upper = p75, ymax = p90),
        stat = "identity"
      )
    show(plt)
  }
}


get_percentiles <- function(results_df, percentiles){
  if(missing(percentiles)){
    percentiles <- c(0.1, 0.25, 0.5, 0.75, 0.9)
  }
  metrics_list <- list()
  for (metric in colnames(results_df)){
    if (metric == "Year"){
      next
    }
    metrics_list[[metric]] = quantile(results_df[metric], probs=percentiles, na.rm=TRUE, names=TRUE, type=8)
  }
  output_data <- t(data.frame(metrics_list))
  colnames(output_data) <- paste("p", percentiles * 100, sep="")
  output_data <- as.data.frame(output_data)
  output_data["Metric"] <- rownames(output_data)
  return(output_data)

}


#' Merges Data Frames by Year Column
#'
#' Just a simple function that can be used with Reduce to merge multiple data frames together by year
merge_list <- function(df1, df2){
  return(merge(df1, df2, by="Year"))
}


convert_season_to_df <- function(season, all_data, rename_metrics, yearRanges){
  print(season)
  if(missing(rename_metrics)){
    rename_metrics <- FALSE
    do_rename <- FALSE
  }else{  # if it's not messing, take the appropriate item from rename_metrics
    rename_metrics <- rename_metrics[[season]]
    do_rename <- TRUE
  }

  season <- all_data[[season]]

  # not using same approach as DRH because of null values - maybe both need to use this though???
  output_data <- t(data.table::rbindlist(season, use.names=FALSE))
  colnames(output_data) <- names(season)
  rownames(output_data) <- yearRanges
  output_data <- data.frame(output_data)

  if(do_rename){
    output_data <- rename_df_to_metrics(output_data, rename_metrics)
  }

  # do this after the field rename
  output_data["Year"] <- rownames(output_data)  # set the year explicitly so we can merge later

  return(output_data)
}


rename_df_to_metrics <- function(dataframe, rename_metrics){
  keys <- names(rename_metrics)
  values <- unlist(rename_metrics)
  map <- setNames(values, keys)  # make the map that we'll use to replace the values
  current_column_names <- colnames(dataframe)  # get the FFC's column names
  current_column_names[] <- map[current_column_names]  # translate them to the metric names
  colnames(dataframe) <- current_column_names  # assign the translated names back to the columns
  return(dataframe)
}

# The following item maps the names of JSON list items coming out of the FFC to the actual metric names
# In cases where there's no matching metric (such as the Julian Day calcs), it uses the nearest metric name
# and appends the change (such as DS_Tim, the real metric, vs. DS_Tim_Julian, the FFC only calculation).
# in a few cases, there was no equivalent match (no_flow_counts), so those were renamed with a seasonal
# prefix so they are traced back, but do not follow the same naming schema/formula.
rename_by_metric <- list(
  "summer" = list(
    "timings" = "DS_Tim_Julian",
    "durations_wet" = "DS_Dur_WS",
    "timings_water" = "DS_Tim",
    "no_flow_counts" = "__summer_no_flow_counts",
    "durations_flush" = "__summer_durations_flush",
    "magnitudes_fifty" = "DS_Mag_50",
    "magnitudes_ninety" = "DS_Mag_90"
  ),
  "winter" = list(
    "timings" = list(
      "ten" = "Peak_Tim_10_Julian",
      "two" = "Peak_Tim_50_Julian",
      "five" = "Peak_Tim_20_Julian",
      "fifty" = "Peak_Tim_2_Julian",
      "twenty" = "Peak_Tim_5_Julian",
      "ten_water" = "Peak_Tim_10",
      "two_water" = "Peak_Tim_50",
      "five_water" = "Peak_Tim_20",
      "fifty_water" = "Peak_Tim_2",
      "twenty_water" = "Peak_Tim_5"
    ),
    "durations" =list(
      "ten" = "Peak_Dur_10",
      "two" = "Peak_Dur_50",
      "five" = "Peak_Dur_20",
      "fifty" = "Peak_Dur_2",
      "twenty" = "Peak_Dur_5"
    ),
    "magnitudes" = list(
      "ten" = "Peak_10",
      "two" = "Peak_50",
      "five" = "Peak_20",
      "fifty" = "Peak_2",
      "twenty" = "Peak_5"
    ),
    "frequencys" = list(
      "ten" = "Peak_Fre_10",
      "two" = "Peak_Fre_50",
      "five" = "Peak_Fre_20",
      "fifty" = "Peak_Fre_2",
      "twenty" = "Peak_Fre_5"
    )
  ),
  "fall" = list(
    "timings" = "FA_Dur_Julian",
    "durations" = "FA_Dur",
    "magnitudes" = "FA_Mag",
    "wet_timings" = "Wet_Tim_Julian",
    "timings_water" = "FA_Tim",
    "wet_timings_water" = "Wet_Tim"
  ),
  "spring" = list(
    "rocs" = "SP_ROC",
    "timings" = "SP_Tim_Julian",
    "durations" = "SP_Dur",
    "magnitudes" = "SP_Mag",
    "timings_water" = "SP_Tim"
  ),
  "fallWinter" = list(
    "bfl_durs" = "Wet_BFL_Dur",
    "baseflows_10" = "Wet_BFL_Mag_10",
    "baseflows_50" = "Wet_BFL_Mag_50"
  )
)
