# Simple Functional Flows Calculator API client

__*Dec 15 2021: We are aware the FFC is currently down because the corresponding API used by this R package is offline. We are working to restore the R package. In the mean time, please take a look at the [python code](https://github.com/leogoesger/func-flow) and [documentation](https://eflow.gitbook.io/ffc-readme/) if you need to generate Functional Flow Metrics.*__

This package is designed to:
1. Process data through the online functional flows calculator
2. Transform that data and return plots of the Dimensionless Reference Hydrograph (DRH) as well as boxplots showing
  the observed versus predicted percentile values for each metric.
3. Have shortcut functions that handle all of this, while exposing the internals so you can access useful intermediate
  products, such as the functional flows calculator results as an R dataframe, in case you need to do more
  complex analysis.
  
It is meant to be used with simply a gage ID, or with a timeseries dataframe of flows along with either a stream
segment COMID or longitude and latitude (it will look up the COMID for you). See Setup and Examples below for more.

[![Code Testing Status](https://travis-ci.org/ceff-tech/ffc_api_client.svg?branch=master)](https://travis-ci.org/ceff-tech/ffc_api_client)

1. [Documentation and Examples](#full-documentation)
2. [Setup](#setup)
3. [Change Log](#change-log)


## Full Documentation and Exmaples
We have moved all documentation and examples to our [documentation website](https://ceff-tech.github.io/ffc_api_client/reference/index.html). A [PDF manual](./manuals/ffcAPIClient_latest.pdf)  is also available.

## Setup
1. If you don't already have `devtools` installed, run `install.packages('devtools')`
in your R console, or install the package any way you prefer.
2. Install this package with `devtools::install_github('ceff-tech/ffc_api_client/ffcAPIClient')`. If you get an error on this installation step, make sure you are using the latest version of the devtools package.
3. Now we need to retrieve your token. In Firefox or Chrome, log into https://eflows.ucdavis.edu. Once logged in, make sure you are on your user profile page at https://eflows.ucdavis.edu/profile and then press F12 on your keyboard to bring up the Inspector, then switch to the Console tab.
4. In the console, type `localStorage.getItem('ff_jwt')` - you may need to type it in yourself instead of pasting (or follow Firefox's
instructions to enable pasting - it will tell you how after you try to paste). Hit Enter to send the command. 
5. Your browser will place text on the line below the command you typed - this is your "token". Save this value and copy it to your clipboard and we'll use it below. This value should stay private - if other people knew the value, they could use it to access your account on eflows.ucdavis.edu!

That's it. You can now run data through the online FFC using this package and process the results.

## Change Log

### Version 0.9.8.2
* [Bugfix] Log messages weren't going to the screen when running CEFF steps with an output folder. They
          once again go to both the screen and the output file. We now have a known issue where when
          it prints the FFC percentiles to the console, they don't come out appropriately (due to
          our logging method) - use the output CSV instead in the meantime.

### Version 0.9.8.1
* [Bugfix] Internal stream class data occasionally had multiple records, which would cause bad parameters
          to be sent to the FFC and a failure in the package. Now checks if there's more than one stream
          class record and uses the first one.


### Version 0.9.8.0
* [Enhancement] The package now checks to make sure it received a valid COMID from web services, which
          helps when the web service is down. It prints a warning if the lookup failed.
* [Enhancement] The package now checks to make sure it obtained at least 24 predicted metric records. If
          it didn't but received some, then it prints a warning. If it received no records, it prints
          an error about the COMID
* [Enhancement] Added a new `$get_comid_online` (default TRUE) flag to FFCProcessor objects. The web service
          that we use to look up COMIDs for gages has been spotty recently, and we returned the option to
          do a lookup locally with spatial data. It will still download a large amount of spatial data for
          NHD segments the first time it runs with the flag set to FALSE, but then future lookups will be
          much faster. It uses the nhdR package, which is not included as a package requirement, and instead
          is installed only if you set `ffc$get_comid_online = FALSE`.

### Version 0.9.7.5
* [Update] Included updated data for peak flow metric predictions into package data. To support this,
          we are temporarily changing the FFCProcessor object to use offline metrics instead of data
          from the TNC API. If you wish to use the API again, set `ffc$predicted_percentiles_online <- TRUE`.
          We will revert it to using online data in the future once the API is updated

### Version 0.9.7.4
* [Enhancement] New code that fills NA values in the 10th percentile column of predicted metrics from the
          TNC API if the 25th percentile column is 0. A warning will be raised if NA values are found
          in the 10th percentile column. Can be turned off by setting `ffc$predicted_percentiles_fill_na_p10`
          to FALSE.

### Version 0.9.7.3
* [Bugfix] Previously, providing a timeseries with a date field that was not named "date" (case sensitive)
          would fail when building the data frame to send to the FFC. This has been fixed, and any date
          field name should be usable, so long as it is provided as a parameter, or set on the `ffc` object
          before running `ffc$set_up`.

### Version 0.9.7.2
* [Update] Fixes for new versions of the eflows API launched recently. Everyone using this package will need
          to upgrade to this version or newer to keep using the package.

### Version 0.9.7.1
* Added function `clean_account` to remove all current runs from the online FFC. Helps with broken accounts
  after recent FFC update. To use, just call `clean_account(token)` after setting your token value into the
  variable named `token`

### Version 0.9.7.0
* [Change] Data sent to the FFC is now filtered according to CEFF Tech Team determined rules - water years
          are dropped if they have more than 7 missing days or more than 2 consecutive missing days (by default). 
          See the documentation for the function `filter_timeseries` for more info. It applies
          to both automatically retrieved gage data and user-provided timeseries. It can
          be disabled by setting timeseries_enable_filtering to FALSe on the FFCProcessor object, but you're
          much better off just disabling it by filling gaps in your data yourself if you need to keep all water
          years.
* [Enhancement] ffcAPIClient now logs both to the console and to a log file in the output folder, including the
          version of the package and any log messages (some R warnings and errors may not show up in the file yet)
* [Change] The package now stops running if you have fewer than 10 years of data *after* the filters implemented
          in this version have run. It warns you, but still runs if you have fewer than 15 years of data. These
          apply whether the data source is gage data or a provided timeseries. To change this behavior,
          change the values of `fail_years_data` and `warn_years_data` on the FFCProcessor object
* [Enhancement] You can now pass minimum and maximum dates for gage data retrieval. Set the values of
          `gage_start_date` and `gage_end_date` on the FFCProcessor object.

### Version 0.9.6.9
* [Bugfix] Fixed issue preventing export of R6 Classes - FFCProcessor and USGSGage should now be available
  for use as the documentation describes

### Version 0.9.6.8
* [Enhancement] Code available for three steps of CEFF process - working on documentation for it still

### Version 0.9.6.7
* [Bugfix] Adjusted to change in FFM API from flows.codefornature.org
* [Enhancement] Code available to support first step of CEFF process

### Version 0.9.6.6
* [Enhancement] New function `force_consistent_naming` sets option to convert peak magnitude metrics to use
  same name format as other magnitude metrics. `Peak_2` becomes `Peak_Mag_2`, etc. Defaults to off to remain
  aligned with CEFF, but if you need metric names to follow a pattern, that will help. See documentation
  for usage.
* [Change] Predicted flow metrics now use a character instead of a factor in the `metric` column.

### Version 0.9.6.5
* [Enhancement] ffc_results dataframe now filters out non-metrics (things starting with __ or ending with _Julian)

### Version 0.9.6.4
* [Bugfix] Handled a condition where the predicted flow metric API returns duplicate values for some metrics

### Version 0.9.6.3
* [Bugfix] Fixed an error where predicted Spring Duration metrics came through as SP_Du

### Version 0.9.6.2
* [Bugfix] Fixed error preventing `evaluate_alteration` from running with warnings about `date_format_string`.

### Version 0.9.6.1
* [Enhancement] Updated plotting to facet each metric with a free Y axis so that all boxplots can be clearly seen. Other
                minor enhancements to plotting, like titles and X axis labels as well.

### Version 0.9.6.0
* [Enhancement] `evaluate_alteration` family of functions now also returns `predicted_wyt_percentiles` in addition to the `predicted_percentiles`.
                The WYT form includes a `wyt` column that includes the water year type of the prediction
* [Change] Using TNC's online API to pull predicted flow metrics instead of internal data by default
* [Change] Under the hood, the code behaves differently - most processing is now being handled in the FFCProcessor class, but more will be moved there

### Version 0.9.5.8
* [Change] Updated the rules used to determine alteration to match new rules for CEFF Appendix F - specifically, we now 
      *always* check that >=50% of observations are within the i80r before declaring something unaltered.

### Version 0.9.5.7
* [Enhancement] `evaluate_alteration` now supports parameter to control plotting (similar to `evaluate_gage_alteration`) and
  documentation has been added for the function.

### Version 0.9.5.6
* [Enhancement] Added the ability to pull predicted metrics from TNC's predicted metrics API instead of from internal data. To 
  use it, set `online=TRUE` when calling `get_predicted_flow_metrics`. It includes one small difference - in the source field,
  values marked as `obs` in the offline data show up as `inferred`.

### Version 0.9.5.5
* [Change] No longer look up gage COMIDs by default due to error-prone nature of lookup near stream junctions. Use
  `force_comid_lookup` parameter to `evaluate_gage_alteration` to enable previous lookup behavior.
* [Enhancement] Added an automatic lookup that corrects bad data from comid lookups and returns the correct COMID. Only
  used for Jones Bar gage right now, but structure is there for if others are found.

### Version 0.9.5.4
* [Breaking Change] Where found, column names have been fully lowercased for consistency, including Metric -> metric and COMID -> comid
* [Breaking Change] Parameter `com_id` to `get_predicted_flow_metrics` was renamed `comid`
* [Enhancement] observed percentiles and predictions both include a `result_type` field, with observed FFC results containing the value "observed" and prediction percentiles fields containing the value "predicted" to allow for merging of the data frames in
some contexts
* [Enhancement] `evaluate_gage_alteration` now attaches a field `gage_id` to `predicted_percentiles`, `observed_percentiles`, 
and `alteration` data frames.
* [Enhancement] observed percentiles now include a comid field to allow for merging and accessing the comid in other contexts
* [Enhancement] `evaluate_alteration` and `evaluate_gage_alteration` now includes a fifth key `alteration` with the assessed flow
alteration scores in a data frame

### Version 0.9.5.3
* [Breaking Change] Results from `evaluate_alteration` and `evaluate_gage_alteration` now use the list key `ffc_percentiles` instead of simply `percentiles` to be clear that the percentiles are from the observed FFC results.
* [Change] Changed quantile processing type to the default of type 7 so that observed FFC data are processed into percentiles the same way that the predicted flow metrics were calculated to minimize resulting error.
* [Enhancement] `evaluate_alteration` and `evaluate_gage_alteration` now includes a fourth key `predicted_percentiles` with the predicted flow metric percentile values so they don't need to be looked up separately.

### Version 0.9.5.2
* [Enhancement] Added `annual` parameter to `assess_alteration` that runs a year over year analysis.

### Version 0.9.5.1
* [Enhancement] New parameter `plot` (boolean) to `evaluate_gage_alteration` controls whether the function produces plots or not

### Version 0.9.5
* [Enhancement] New `assess_alteration` function returns a data frame with alteration results - documentation forthcoming.
* [Change] Warning when can't determine stream segment's hydrogeomorphic type has been downgraded to a print statement.

### Version 0.9.4.2
* [Breaking Change] The client now detects and sends the appropriate parameters to the FFC online for the stream class that
                  it detects based on the COMID. If you are using low-level functions such as `get_ffc_results_for_df`, then
                  you must provide an argument `comid` - check the documentation for which functions need it.
                  Further,`process-data` now requires that the stream parameters be provided to it. I recommend moving to
                  something like `get_ffc_results_for_df` as process_data may soon be moved to be internal only.

### Version 0.9.4.1
* [Enhancement] New code to support sending the correct stream class parameters to the FFC - includes the ability to identify
    stream classes by COMID, but not yet send the parameters
* [Change] Data loading code made more generic, and potentially faster - multiple calls to get predicted flow metrics
    should not result in reloading the dataset.

### Version 0.9.4
* [Breaking Change] List item `$ffc_results_df` returned from `evaluate_alteration` functions changed to `$ffc_results` for
    consistency with FFCProcessor object and allowing for more flexibility in the future.
* [Enhancement] Basic alteration assessment capabilities included. Require more testing before use
* [Documentation] Reworking documentation to make best workflows clearer

### Version 0.9.3
* [Enhancement] Can now provide a time format string to `evaluate_alteration` - it will use that to read the values
  in the time field and reformat them to send to the FFC as needed.
* [Bugfix] FFC results no longer fail to transform if one flow metric is entirely NULL

