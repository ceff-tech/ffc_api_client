#' USGS Gage Retrieval Tools
#'
#' This class retrieves data for a USGS gage.
#'
#' @details
#'
#' @examples
#' #library(ffcAPIClient)
#' #gageid <- 11427000
#' #gage <- USGSGage$new()
#' #gage$id <- gageid
#' #gage$get_data()
#' #gage$get_comid()
#' #gage$comid
#' #14996611
#' #ffcAPIClient::get_predicted_flow_metrics(gage$comid)
#'         metric    COMID          p10          p25        p50          p75          p90 source
#'      DS_Dur_WS 14996611 1.051875e+02 1.273438e+02   154.0625 1.785563e+02 1.953908e+02  model
#'      DS_Mag_50 14996611 4.998793e+01 6.732828e+01   104.4028 1.464183e+02 1.882733e+02  model
#'      DS_Mag_90 14996611 9.314097e+01 1.291930e+02   173.6844 2.382053e+02 3.393799e+02  model
#'         DS_Tim 14996611 2.720000e+02 2.823875e+02   296.8875 3.070000e+02 3.210167e+02  model
#'         FA_Dur 14996611 2.000000e+00 3.000000e+00     4.0000 6.000000e+00 8.000000e+00    obs
#'         FA_Mag 14996611 1.294269e+02 1.886283e+02   289.6838 4.540329e+02 8.514823e+02  model
#'         FA_Tim 14996611 7.816667e+00 1.400000e+01    24.6250 2.900000e+01 4.217000e+01  model
#'        Peak_10 14996611 1.243107e+04 1.947545e+04 22830.3355 3.124928e+04 3.767889e+04  model
#'        Peak_20 14996611 8.078893e+03 1.227363e+04 20218.4829 2.087196e+04 2.087196e+04  model
#'        Peak_50 14996611 3.532988e+03 7.350986e+03  8542.1191 8.969386e+03 8.969386e+03  model
#'    Peak_Dur_10 14996611 1.000000e+00 1.000000e+00     1.0000 2.000000e+00 4.000000e+00    obs
#'    Peak_Dur_20 14996611 1.000000e+00 1.000000e+00     2.0000 3.000000e+00 6.000000e+00    obs
#'    Peak_Dur_50 14996611 1.000000e+00 1.000000e+00     4.0000 1.000000e+01 2.900000e+01    obs
#'    Peak_Fre_10 14996611 1.000000e+00 1.000000e+00     1.0000 1.000000e+00 2.000000e+00    obs
#'    Peak_Fre_20 14996611 1.000000e+00 1.000000e+00     1.0000 2.000000e+00 3.000000e+00    obs
#'    Peak_Fre_50 14996611 1.000000e+00 1.000000e+00     2.0000 3.000000e+00 5.000000e+00    obs
#'         SP_Dur 14996611 4.700000e+01 5.900000e+01    72.0000 9.527500e+01 1.215417e+02  model
#'         SP_Mag 14996611 1.067727e+03 1.662598e+03  2489.0563 3.771512e+03 5.809320e+03  model
#'         SP_ROC 14996611 3.845705e-02 4.863343e-02     0.0625 8.132020e-02 1.141117e-01    obs
#'         SP_Tim 14996611 1.607717e+02 1.905000e+02   218.7500 2.354750e+02 2.447583e+02  model
#'    Wet_BFL_Dur 14996611 7.633333e+01 1.073000e+02   141.1958 1.633750e+02 1.875000e+02  model
#' Wet_BFL_Mag_10 14996611 1.519943e+02 1.960031e+02   278.2581 4.384614e+02 5.489183e+02  model
#' Wet_BFL_Mag_50 14996611 4.148992e+02 5.902507e+02   924.1728 1.175461e+03 1.426576e+03  model
#'        Wet_Tim 14996611 4.937500e+01 5.905000e+01    73.0000 8.835625e+01 1.035083e+02  model
#'
#' @export
USGSGage <- R6::R6Class("USGSGage", list(

  id = NA,
  comid = NA,  # The COMID of the stream segment this gage is on.
  timeseries_data = NA,
  latitude = NA,
  longitude = NA,

  #' @details
  #' Validates that gage is ready to run requests
  #'
  #' Internal method. Checks parameters to make sure they're ready for other methods on the object.
  validate = function(latlong){
    if(missing(latlong)){
      latlong = FALSE
    }

    if(is.na(self$id)){
      stop("Must set id property of USGSGage before calling other gage functions")
    }

    if(latlong == TRUE && (is.na(self$latitude) || is.na(self$longitude))){
      stop("Latitude or Longitude is missing for gage, but required. Either set it manually, or
           run get_data, which should set it automatically.")
    }
  },

  get_data = function(){

    self$validate()

    # check metadata (flow is 00060, daily mean is 00003)
    usgs_daily_1 <- dataRetrieval::whatNWISdata(siteNumber=self$id, service='dv',
                             parameterCd = '00060',
                             statCd="00003")

    # save the latitude and longitude
    self$latitude <- usgs_daily_1$dec_lat_va
    self$longitude <- usgs_daily_1$dec_long_va

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

  #' @details
  #' Looks up the COMID for this gage
  #'
  #' This method looks up the COMID for the gage and sets the comid attribute. It does not return
  #' the COMID. It returns this object for chaining. The gage's id, latitude, and longitude
  #' attributes must be set before running this. latitude and longitude can be set manually,
  #' or by running get_data(). Can be error prone near stream junctions. If you have the means
  #' to get a reliable COMID for a gage, do so - in this method, we look up the stream
  #' segment by long/lat using nhdPlusTools.
  #'
  get_comid = function(){
    # in some cases, lat/long produce the wrong COMID. We have a list where we store corrected values - if this gage
    # ID is in the list, just return that value, otherwise, continue below.
    overridden_gage_id <- gage_comids[[as.character(self$id)]]
    if(!is.null(overridden_gage_id)){
      print(paste("Using overridden comid for gage of", overridden_gage_id))
      self$comid = overridden_gage_id

    }else{

      self$validate(latlong=TRUE)
      self$comid <- get_comid_for_lon_lat(self$longitude, self$latitude)

    }

    invisible(self)  # return itself invisibly, but after setting the COMID
  },

  get_predicted_metrics = function(force_comid_lookup){
    if(missing(force_comid_lookup)){
      force_comid_lookup <- FALSE
    }

    if(is.na(self$comid) && force_comid_lookup){
      self$get_comid()
    }

    if(is.na(self$comid)){
      stop("Unable to get COMID for gage. Set gage$comid manually before running or set force_comid_lookup to TRUE - it can give inaccurate data for gages near stream junctions though, so it is FALSE by default.")
    }
    return(get_predicted_flow_metrics(self$comid))
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
  gage$id <- gage_id
  gage$get_data()
  return(gage$timeseries_data)
}

#' Where we know the lat/long will produce the wrong COMID for a gage (such as giving us a nearby tributary and not the mainstem,
#' or vice versa), we can hardcode their COMIDs here to make sure we get the correct location. We haven't looked through all
#' gages to make sure every one is correct, but as we find them, this will help improve results and reduce error
gage_comids <- list(
  '11417500' = 8060893
)
