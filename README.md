# Simple Functional Flows Calculator API client
This is a quick take on using the eflows.ucdavis.edu API instead of installing the Python
calculator code on a local machine. Setup is simple - the R code will install any missing
packages when run, and all you need is to retrieve a token from your account on eflows.ucdavis.edu

Check out examples.Rmd to see the usage of this code - right now it can send a data frame to
the API for processing, retrieve the results, and process the DRH data into an R data frame.
Other processing that interfaces with the Colorado School of Mines code could be added easily.

## Setup
1. If you don't already have `devtools` installed, run `install.packages('devtools')`
in your R console, or install the package any way you prefer.
2. Install this package with `devtools::install_github('ceff-tech/ffc_api_client/ffcAPIClient')`
3. Now we need to retrieve your token. In Firefox (only tested there), log into https://eflows.ucdavis.edu. Once logged in, press F12 to bring up the Inspector, then switch to the Console tab.
4. In the console, type `localStorage.getItem('ff_jwt')` - you may need to type it in yourself instead of pasting (or follow Firefox's
instructions to enable pasting - it will tell you how after you try to paste). Hit Enter to send the command. 
5. Firefox will place text on the line below the command you typed - this is your "token". Save this value and we'll use it below

That's it. You can now run data through the ffc using the online calculator. Make sure to give each run a unique name for this
code to work correctly!

## Usage Example
```r
# Initialize a Run
test_data <- example_gagedata()  # just get some fake gage data - based on Daniel Philippus' code - you can build your own data frame here
ffcAPIClient::set_token(YOUR_TOKEN_VALUE_IN_QUOTES) # you'll need to get your own of this - see above
results <- ffcAPIClient::get_ffc_results_for_df(test_data)  # send it to the FFC online to process

# Retrieve Results and Plot
## get the DRH data as a data frame with percentiles for columns and days for rows
drh_data <- ffcAPIClient::get_drh(results) 
plot(drh_data$seventy_five, type="l")  # plot the seventy-fifth percentile DRH
```

## Predicted Flow Metrics
I'm working to get the code to a state to compare the percentiles generated from the observed data
and the percentiles predicted by modeling. As part of this, the code includes the full results
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
1090875        Peak_20 8058513 5.456749e+03 8.858951e+03 13062.81469 1.348278e+04 1.642180e+04  model
1231121        Peak_50 8058513 2.903039e+03 4.493501e+03  5484.65786 6.384782e+03 1.405851e+04  model
1355941    Peak_Dur_10 8058513 1.000000e+00 1.000000e+00     1.00000 2.000000e+00 4.000000e+00    obs
1426661    Peak_Dur_20 8058513 1.000000e+00 1.000000e+00     2.00000 3.000000e+00 6.000000e+00    obs
1497381    Peak_Dur_50 8058513 1.000000e+00 1.000000e+00     4.00000 1.000000e+01 2.900000e+01    obs
1568101    Peak_Fre_10 8058513 1.000000e+00 1.000000e+00     1.00000 1.000000e+00 2.000000e+00    obs
1638821    Peak_Fre_20 8058513 1.000000e+00 1.000000e+00     1.00000 2.000000e+00 3.000000e+00    obs
1709541    Peak_Fre_50 8058513 1.000000e+00 1.000000e+00     2.00000 3.000000e+00 5.000000e+00    obs
1795687         SP_Dur 8058513 4.600000e+01 5.500000e+01    67.86250 8.962500e+01 1.210167e+02  model
1935933         SP_Mag 8058513 1.338260e+03 1.826367e+03  2632.40321 4.145245e+03 6.601865e+03  model
2060753         SP_ROC 8058513 3.845705e-02 4.863343e-02     0.06250 8.132020e-02 1.141117e-01    obs
2146899         SP_Tim 8058513 1.805000e+02 2.149063e+02   232.00000 2.414292e+02 2.515050e+02  model
2287145    Wet_BFL_Dur 8058513 6.648750e+01 9.409375e+01   137.38750 1.738125e+02 1.970433e+02  model
2427391 Wet_BFL_Mag_10 8058513 1.370541e+02 2.052893e+02   333.09236 4.704166e+02 5.683843e+02  model
2567637 Wet_BFL_Mag_50 8058513 4.369753e+02 6.272972e+02   824.51279 1.083330e+03 1.360226e+03  model
2707883        Wet_Tim 8058513 4.638500e+01 5.857500e+01    72.42500 9.511667e+01 1.187900e+02  model
```

## Considerations
This code was written to avoid setup headaches associated with getting the existing code set up on many machines and enable many people
to use it. That said, it's not as feature-complete, and may be slower than running everything on your own computer. As currently written,
certain items will slow down the more you run data through the calculator, since it currently retrieves *all* results every time you
want to get a single result. But it does clean up after itself and won't leave behind
runs you execute with this code.
