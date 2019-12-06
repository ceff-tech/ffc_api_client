# Simple Functional Flows Calculator API client
This is a quick take on using the eflows.ucdavis.edu API instead of installing the Python
calculator code on a local machine. Setup is simple - the R code will install any missing
packages when run, and all you need is to retrieve a token from your account on eflows.ucdavis.edu

Check out examples.Rmd to see the usage of this code - right now it can send a data frame to
the API for processing, retrieve the results, and process the DRH data into an R data frame.
Other processing that interfaces with the Colorado School of Mines code could be added easily.

# Setup
1. download ffc_api_client.Rmd and place it in your R working directory
2. load it into your own R code with
```r
api_client_code <- file.path(getwd(), "ffc_api_client.R")
source(api_client_code)
```
3. Now we need to retrieve your token. In Firefox (only tested there), log into https://eflows.ucdavis.edu. Once logged in, press F12 to bring up the Inspector, then switch to the Console tab.
4. In the console, type `localStorage.getItem('ff_jwt')` - you may need to type it in yourself instead of pasting (or follow Firefox's
instructions to enable pasting - it will tell you how after you try to paste). Hit Enter to send the command. 
5. Firefox will place text on the line below the command you typed - this is your "token". After the `source` line, type `TOKEN = ""` and place your token between the quotes.

That's it. You can now run data through the ffc using the online calculator. Make sure to give each run a unique name for this
code to work correctly!

# Usage Example
```r
# Load the FFC API Client code
api_client_code <- file.path(getwd(), "ffc_api_client.R")
source(api_client_code)

# Initialize a Run
test_data <- example_gagedata()  # just get some fake gage data - based on Daniel Philippus' code
TOKEN = ""  # you'll need to get your own of this - see README
process_data(test_data, "10/1", name="r_client_example")  # send it to the FFC online to process

# Retrieve Results and Plot
## get the DRH data as a data frame with percentiles for columns and days for rows
drh_data <- get_drh_for_name(name="r_client_example") 
plot(drh_data$seventy_five, type="l")  # plot the seventy-fifth percentile DRH
```

# Considerations
This code was written to avoid setup headaches associated with getting the existing code set up on many machines and enable many people
to use it. That said, it's not as feature-complete, and may be slower than running everything on your own computer. As currently written,
certain items will slow down the more you run data through the calculator, since it currently retrieves *all* results every time you
want to get a single result. This could be optimized out, and this is currently just a proof of concept.