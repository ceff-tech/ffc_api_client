USGSGage <- R6::R6Class("USGSGage", list(
  gage_id = NA,
  timeseries_data = NA,
  validate = function(){
    if(is.na(self$gage_id)){
      stop("Must set gage_id property of USGSGage before calling get_data")
    }
  },
  get_data = function(){

    self$validate()

    # check metadata (flow is 00060, daily mean is 00003)
    usgs_daily_1 <- dataRetrieval::whatNWISdata(siteNumber=self$gage_id, service='dv',
                             parameterCd = '00060',
                             statCd="00003")
    usgs_daily_2 <- dplyr::select(usgs_daily_1, site_no, station_nm, dec_lat_va, dec_long_va,
           dec_coord_datum_cd, alt_va, huc_cd, data_type_cd,
           parm_cd, stat_cd, begin_date:count_nu)
    # rename cols
    usgs_daily_3 <- dplyr::rename(usgs_daily_2, interval=data_type_cd, lat = dec_lat_va, lon=dec_long_va,
           huc8=huc_cd, site_id=site_no, date_begin=begin_date,
           date_end=end_date, datum=dec_coord_datum_cd, elev_m=alt_va)
    # add total year range
    usgs_daily <- dplyr::mutate(usgs_daily_3, yr_begin = lubridate::year(date_begin),
           yr_end = lubridate::year(date_end),
           yr_total = yr_end-yr_begin)

    # select and get flow data for station/param if over 10 years:
    if(usgs_daily$yr_total>10){
        daily_df_1 <- dataRetrieval::readNWISdv(siteNumbers=usgs_daily$site_id, parameterCd = "00060")
        daily_df_2 <- dataRetrieval::addWaterYear(daily_df_1)
        daily_df_3 <- dplyr::rename(daily_df_2, flow=X_00060_00003, date=Date, gage=site_no,
                 flow_flag=X_00060_00003_cd)
        daily_df <- dplyr::mutate(daily_df_3, date=format(as.Date(date),'%m/%d/%Y'))
      }else{
        print("Less than 10 years of data...try again")
        return(NULL)
      }

    self$timeseries_data <- daily_df
    invisible(self)

  },
  get_comid_for_gage = function(){
    self$validate()
  }
))

#' Retrieves USGS timeseries gage data
#'
#' This is just a helper function that calls the gage constructor, gets the flows and returns them in one step.
#' Useful in situations where we don't need the flexibility of the USGSGage class
#'
#' @param gage_id integer. The USGS Gage ID value for the gage you want to return timeseries data for
#' @return dataframe. Will include a flow field (CFS) and a date field (MM/DD/YYYY)
#'
#' @export
get_usgs_gage_data <- function(gage_id){
  gage = USGSGage$new()
  gage$gage_id <- gage_id
  gage$get_data()
  return(gage$timeseries_data)
}
