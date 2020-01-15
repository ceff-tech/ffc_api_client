stream_class_data <- read.csv("data-raw/geomorphic_stream_classification.csv")

# let's make the stream class a factor with levels for each stream class so we can look up by class
stream_class_data$CLASS_CODE <- "SM"
stream_class_data$CLASS_CODE[stream_class_data$CLASS == 2] <- "HSR"
stream_class_data$CLASS_CODE[stream_class_data$CLASS == 3] <- "LSR"
stream_class_data$CLASS_CODE[stream_class_data$CLASS == 4] <- "WS"
stream_class_data$CLASS_CODE[stream_class_data$CLASS == 5] <- "GW"
stream_class_data$CLASS_CODE[stream_class_data$CLASS == 6] <- "PGR"
stream_class_data$CLASS_CODE[stream_class_data$CLASS == 7] <- "FER"
stream_class_data$CLASS_CODE[stream_class_data$CLASS == 8] <- "RGW"
stream_class_data$CLASS_CODE[stream_class_data$CLASS == 9] <- "HLP"
stream_class_data$CLASS_CODE <- as.factor(stream_class_data$CLASS_CO)

save(stream_class_data, file = "data/stream_class_data.rda")
