
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
    ggplot2::theme_classic(base_family = "Roboto Condensed") +
    ggplot2::labs(title="Dimensionless Hydrograph", x="Julian Day",
         y="Daily median flow / Avg annual flow",
         caption="Daily median flow with 10/90 percentiles (light blue), and 25/75 percentiles in purple")

  if(!is.null(output_path)){
    ggplot2::ggsave(filename = output_path, width = 7, height = 5, units = "in", dpi=300)
  }

  return(drh_plot)
}
