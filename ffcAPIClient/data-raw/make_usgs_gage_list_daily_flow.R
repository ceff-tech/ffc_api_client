make_daily_usgs_ca_gage_list <- function(paramCD=c("00060")) {
  
  # gages with daily flow data
  ca_usgs_gages <- dataRetrieval::whatNWISdata(stateCd="California", service="dv", parameterCd=paramCD) %>% 
    dplyr::select(site_no, station_nm, dec_lat_va, dec_long_va,
                  dec_coord_datum_cd, alt_va, huc_cd, data_type_cd,
                  parm_cd, stat_cd, begin_date:count_nu) %>%
    # rename cols
    dplyr::rename(interval=data_type_cd, lat = dec_lat_va, lon=dec_long_va,
                  huc8=huc_cd, site_id=site_no, date_begin=begin_date,
                  date_end=end_date, datum=dec_coord_datum_cd, elev_m=alt_va) %>%
    # filter missing vals
    dplyr::filter(!is.na(lon)) %>%
    # now make sure spatially distinct
    dplyr::distinct(site_id, .keep_all=TRUE) %>% 
    sf::st_as_sf(coords=c("lon","lat"), crs=4269, remove=FALSE) 
  return(ca_usgs_gages)
}  


save_usgs_gage_list <- function(output_path){
  if(missing(output_path)){
    # we'll make it this way since only the package root is guaranteed to exist here.
    package_root <- system.file(package="ffcAPIClient")
    output_path <- paste(package_root, "R", "usgs_ca_daily_flow_gages.rda", sep="/")
  }
  save(ca_usgs_gages, file=output_path)
}
