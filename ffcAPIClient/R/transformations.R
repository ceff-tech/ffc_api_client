
# returns the dimensionless reference hydrograph results as a data frame
#' @export
get_drh <- function(results){
  # Pulls the DRH data for a named result and transforms it into a data frame that can be used for plotting and analysis
  drh <- t(do.call(rbind.data.frame, results$DRH))  # rowbind, but transpose
  rownames(drh) <- seq(1,366)  # reset the rownames to days
  return(data.frame(drh))  # convert to data frame and return
}
