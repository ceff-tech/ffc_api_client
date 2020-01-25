current_version <- "0.9.5.2"  # it'd be nice to have this just find the latest file in the folder instead

devtools::document()

# export PDF manual - it will use the package name and version number by default
devtools::build_manual(path = "../manuals")
file.copy(paste("../manuals/ffcAPIClient_", current_version, ".pdf", sep=""), "../manuals/ffcAPIClient_latest.pdf", overwrite = TRUE)

devtools::build_site(preview = FALSE, examples = FALSE)
