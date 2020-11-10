
get_predicted_flow_metrics_sql <- function(com_id, db_path){

  predicted_metrics_db <- RSQLite::dbConnect(RSQLite::SQLite(), db_path)

  sql_query <- paste("

    select flow_metric.metric,
    	stream_segment.com_id,
    	scd.pct_10,
    	scd.pct_25,
    	scd.pct_50,
    	scd.pct_75,
    	scd.pct_90
    from
    	belleflopt_streamsegment as stream_segment
    	LEFT JOIN belleflopt_segmentcomponent as sc ON sc.stream_segment_id = stream_segment.id
    	LEFT JOIN belleflopt_segmentcomponentdescriptor_flow_components as scdfc ON scdfc.segmentcomponent_id = sc.id
    	LEFT JOIN belleflopt_segmentcomponentdescriptor as scd ON scd.id = scdfc.segmentcomponentdescriptor_id
    	LEFT JOIN belleflopt_flowmetric as flow_metric ON flow_metric.id = scd.flow_metric_id
    WHERE
    	stream_segment.com_id = \"", com_id, "\"
  ", sep="")

  return(RSQLite::dbGetQuery(predicted_metrics_db, sql_query))
}


get_all_predicted_flow_metrics <- function(db_path){
  predicted_metrics_db <- RSQLite::dbConnect(RSQLite::SQLite(), db_path)

  sql_query <- "
    select flow_metric.metric,
    	stream_segment.com_id,
    	scd.pct_10,
    	scd.pct_25,
    	scd.pct_50,
    	scd.pct_75,
    	scd.pct_90
    from
    	belleflopt_streamsegment as stream_segment
    	LEFT JOIN belleflopt_segmentcomponent as sc ON sc.stream_segment_id = stream_segment.id
    	LEFT JOIN belleflopt_segmentcomponentdescriptor_flow_components as scdfc ON scdfc.segmentcomponent_id = sc.id
    	LEFT JOIN belleflopt_segmentcomponentdescriptor as scd ON scd.id = scdfc.segmentcomponentdescriptor_id
    	LEFT JOIN belleflopt_flowmetric as flow_metric ON flow_metric.id = scd.flow_metric_id"

  return(RSQLite::dbGetQuery(predicted_metrics_db, sql_query))
}

get_all_raw_predicted_flow_metrics <- function(input_folder){
  # adapted from https://stackoverflow.com/questions/30242065/trying-to-merge-multiple-csv-files-in-r
  filenames <- list.files(path=input_folder, full.names=TRUE)
  filenames <- filenames[grepl("\\.csv$", filenames)]
  print(filenames)
  datalist <- lapply(filenames, function (x) utils::read.csv(file=x, header=TRUE))
  results <- Reduce(function(x,y) rbind(x,y), datalist)

  drop_fields <- c("alteration", "gage_id", "observed_years")
  names(results)[names(results) == 'ffm'] <- 'metric'  # rename the FFM field to metric
  #names(results)[names(results) == 'COMID'] <- 'comid'  # rename the COMID field to comid for case consistency

  results <- results[, !names(results) %in% drop_fields]  # get rid of any extraneous fields
  # remove duplicates
  results <- results[!duplicated(results[,c("metric", "comid")]), ]  # deduplicate on unique comid/metric combo

  return(results)
}


# This is the only function you typically need to run to update the data - it calls the get_all_predicted_flow_metrics code above
save_all_predicted_flow_metrics <- function(input_folder, output_path){
  if(missing(output_path)){
    # we'll make it this way since only the package root is guaranteed to exist here.
    package_root <- system.file(package="ffcAPIClient")
    output_path <- paste(package_root, "data", "flow_metrics.rda", sep="/")
    print(paste("Saving Output to ", output_path))
  }
  flow_metrics <- get_all_raw_predicted_flow_metrics(input_folder=input_folder)
  save(flow_metrics, file=output_path)
}
