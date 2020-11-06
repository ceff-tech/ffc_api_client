# Simple Functional Flows Calculator API client
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

1. [Documentation](#full-documentation)
2. [Setup](#setup)
3. [Usage Examples](#usage-examples)
4. [Predicted Flow Metrics](#predicted-flow-metrics)
6. [Change Log](#change-log)


## Full Documentation
There are many examples below, including instructions on how to set up and use the core parts of the package.
However, full documentation of the package is included only in the [online documentation](https://ceff-tech.github.io/ffc_api_client/reference/index.html) or in the [PDF manual](./manuals/ffcAPIClient_latest.pdf).

## Setup
1. If you don't already have `devtools` installed, run `install.packages('devtools')`
in your R console, or install the package any way you prefer.
2. Install this package with `devtools::install_github('ceff-tech/ffc_api_client/ffcAPIClient')`
3. Now we need to retrieve your token. In Firefox or Chrome, log into https://eflows.ucdavis.edu. Once logged in, press F12 on your keyboard to bring up the Inspector, then switch to the Console tab.
4. In the console, type `localStorage.getItem('ff_jwt')` - you may need to type it in yourself instead of pasting (or follow Firefox's
instructions to enable pasting - it will tell you how after you try to paste). Hit Enter to send the command. 
5. Your browser will place text on the line below the command you typed - this is your "token". Save this value and copy it to your clipboard and we'll use it below. This value should stay private - if other people knew the value, they could use it to access your account on eflows.ucdavis.edu!

That's it. You can now run data through the online FFC using this package and process the results.

## Usage Examples

### Following the CEFF Steps

#### Step One
```r
library(ffcAPIClient)

ffc <- FFCProcessor$new()  # make a new object we can use to run the commands

# configure the object and run CEFF step 1 plus outputs

ffc$step_one_functional_flow_results(gage_id=11336000,
     token=token,
     output_folder = "C:/Users/myusername/Downloads/test")
```
That command will output DOH data + image, observed annual data, observed percentiles, and observed plots to the specified folder. It will output the percentiles to the console as well.

It also makes that data available for further analysis on the object `ffc`, so you can now access the FFC results by year as `ffc$ffc_results`, the processed percentiles as `ffc$ffc_percentiles`, and the underlying DOH data as `ffc$doh_data` if you want to view them again in R or feed them into other code and visualizations.

It is highly recommended that you provide the `output_folder` parameter, as the package will also output its log file there, in addition to plots and CSV results. The log will help track the history of the results in case of future changes.

#### Step Two
For step 2, we now run simply `ffc$step_two_explore_ecological_flow_criteria()` and it continues where we left off. In fact, *everything* is run in step 1, and we just control what is output with these functions. This outputs the predicted metric percentile data as a CSV and to the console, and plots the predicted values on their own.

Now we can access `ffc$predicted_percentiles` if we want to feed that into other processing or visualizations too.

#### Step Three
For step 3, same thing. Run `ffc$step_three_assess_alteration()` and get the alteration data frame saved as a CSV and printed to the console. Full comparison plots of predicted vs. observed percentiles are output now to the screen and to the folder specified in step 1 (where everything is saved). 

And now we get one more thing we can access - `ffc$alteration` contains the alteration assessment results. In fact everything is accessible after step 1, but conceptually, this is the data frame that corresponds with this step.

There's also more that's available as part of the `ffc` object, but we'll document that elsewhere.


### Other examples
It's recommended you run the steps above on your own, but the package includes other ways to run similar workflows for gage data
or for timeseries data of your own.
```r
# If you have a gage and a token, you can get all results simply by running
ffcAPIClient::evaluate_gage_alteration(gage_id = 11427000, token = "your_token", comid = segment_comid, plot_output_folder = "C:/Users/youruser/Documents/NFA_Gage_Alteration")
# output_folder is optional. When provided, it will save plots there. It will show plots regardless.
# in the past, we looked up the comid for you, but it's error prone - see function documentation for details
# and how to optionally re-enable the lookup.

# If you have a data frame with flow and date fields that isn't a gage, you can run
ffcAPIClient::evaluate_alteration(timeseries_df = your_df, token = "your_token", plot_output_folder = "C:/Users/youruser/Documents/Timeseries_Alteration", comid=yoursegmentcomid)
# it also *REQUIRES* you provide either a comid argument with the stream segment COMID, or both
# longitude and latitude arguments.
# If your dates are in a different format, provide the format string as argument date_format_string

```
Both of these functions plot results immediately and optionally save the plots to the output folder. They
also return a FFCProcessor object that has items named `ffc_results_df`, `percentiles`, and `drh`, so you can access the transformed
data directly for additional calculations, in addition to other available data.
* `ffc_results` includes the raw data from the functional flows calculator for each flow metric by 
   day of water year. 
* `ffc_percentiles` includes the calculated 10th, 25th, 50th, 75th, and 90th percentiles for each metric
* `alteration` data frame includes the assessed alteration of each metric using CEFF Appendix F Rules.
* `predicted_percentiles` includes the same percentiles as predicted for each metric for assessing the observed ffc
    results against predicted unaltered flow.
* `drh_data` contains the raw DRH data with columns for percentiles and rows for days of water year.

See the [documentation](#documentation) for more information on these results.

## Predicted Flow Metrics
This package compares the percentiles generated from the observed data
and the percentiles predicted by modeling. As part of this functionality, the code includes the full results
of the modeling output as a data frame accessible in `ffcAPIClient::flow_metrics`. More practically,
if you have a variable `com_id` that stores an NHD stream segment identifier (COMID), then you
can also use `ffcAPIClient::get_predicted_flow_metrics(com_id)` to retrieve a data frame with
only the results for that segment. For example, for the Goodyear's Bar reference gage
segment on the North Yuba:
```
> ffcAPIClient::get_predicted_flow_metrics("8058513")
                Metric   COMID          p10          p25         p50          p75          p90 source
38433        DS_Dur_WS 8058513 8.467500e+01 1.146312e+02   145.00000 1.765000e+02 2.015200e+02  model
178679       DS_Mag_50 8058513 3.550966e+01 5.372067e+01    83.01238 1.227657e+02 1.446242e+02  model
318925       DS_Mag_90 8058513 7.209266e+01 1.018497e+02   156.52111 2.332115e+02 3.339129e+02  model
459171          DS_Tim 8058513 2.788200e+02 2.880000e+02   300.90000 3.115000e+02 3.241325e+02  model
583991          FA_Dur 8058513 2.000000e+00 3.000000e+00     4.00000 6.000000e+00 8.000000e+00    obs
670137          FA_Mag 8058513 1.129055e+02 1.711441e+02   270.44481 4.731658e+02 8.309241e+02  model
810383          FA_Tim 8058513 7.830000e+00 1.444375e+01    23.46667 3.002500e+01 4.729750e+01  model
950629         Peak_10 8058513 8.031502e+03 1.316898e+04 19158.34402 2.434368e+04 2.613562e+04  model
1090875        Peak_5 8058513 5.456749e+03 8.858951e+03 13062.81469 1.348278e+04 1.642180e+04  model
1231121        Peak_2 8058513 2.903039e+03 4.493501e+03  5484.65786 6.384782e+03 1.405851e+04  model
1355941    Peak_Dur_10 8058513 1.000000e+00 1.000000e+00     1.00000 2.000000e+00 4.000000e+00    obs
1426661    Peak_Dur_5 8058513 1.000000e+00 1.000000e+00     2.00000 3.000000e+00 6.000000e+00    obs
1497381    Peak_Dur_2 8058513 1.000000e+00 1.000000e+00     4.00000 1.000000e+01 2.900000e+01    obs
1568101    Peak_Fre_10 8058513 1.000000e+00 1.000000e+00     1.00000 1.000000e+00 2.000000e+00    obs
1638821    Peak_Fre_5 8058513 1.000000e+00 1.000000e+00     1.00000 2.000000e+00 3.000000e+00    obs
1709541    Peak_Fre_2 8058513 1.000000e+00 1.000000e+00     2.00000 3.000000e+00 5.000000e+00    obs
1795687         SP_Dur 8058513 4.600000e+01 5.500000e+01    67.86250 8.962500e+01 1.210167e+02  model
1935933         SP_Mag 8058513 1.338260e+03 1.826367e+03  2632.40321 4.145245e+03 6.601865e+03  model
2060753         SP_ROC 8058513 3.845705e-02 4.863343e-02     0.06250 8.132020e-02 1.141117e-01    obs
2146899         SP_Tim 8058513 1.805000e+02 2.149063e+02   232.00000 2.414292e+02 2.515050e+02  model
2287145    Wet_BFL_Dur 8058513 6.648750e+01 9.409375e+01   137.38750 1.738125e+02 1.970433e+02  model
2427391 Wet_BFL_Mag_10 8058513 1.370541e+02 2.052893e+02   333.09236 4.704166e+02 5.683843e+02  model
2567637 Wet_BFL_Mag_50 8058513 4.369753e+02 6.272972e+02   824.51279 1.083330e+03 1.360226e+03  model
2707883        Wet_Tim 8058513 4.638500e+01 5.857500e+01    72.42500 9.511667e+01 1.187900e+02  model
```

## Change Log

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

