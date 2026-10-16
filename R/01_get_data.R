################################################################################
# 01_get_data.R
#
# Retrieve raw water-quality observations from the PREP API.
#
# Outputs:
#   data/raw_water_quality_observations.csv
#   data/raw_water_quality_retrieval.csv
#
# This script does not:
#   - apply quality-control filters
#   - collapse measurements into sampling events
#   - calculate statistics or create figures
#
# Event-level averaging is handled separately in 02_clean_data.R.
################################################################################

# Load packages
library(httr)
library(jsonlite)
library(dplyr)
library(purrr)

################################################################################
# 1. Setup
################################################################################

# Run this script from the RStudio project root.
BASE_URL <- "http://data.prepestuaries.org:3001"

DATA_DIR <- file.path("data")

RAW_DATA_FILE <- file.path(
  DATA_DIR,
  "raw_water_quality_observations.csv"
)

RETRIEVAL_LOG_FILE <- file.path(
  DATA_DIR,
  "raw_water_quality_retrieval.csv"
)

dir.create(DATA_DIR, recursive = TRUE, showWarnings = FALSE)

STATION_CODES <- c(
  "GRBGB",
  "GRBCML",
  "GRBUPR"
)

VARIABLE_CODES <- c(
  "Light Attenuation Coefficient",
  "Solids, Suspended Total",
  "Chlorophyll A, Corrected For Pheophytin",
  "Chlorophyll A, Uncorrected For Pheophytin"
)

################################################################################
# 2. Helper functions
################################################################################

# Retrieve a table from the PREP API.
get_prep <- function(endpoint, query = list()) {

  response <- GET(
    url = paste0(BASE_URL, endpoint),
    query = query,
    timeout(60)
  )

  stop_for_status(response)

  response_text <- content(
    response,
    "text",
    encoding = "UTF-8"
  )

  data <- fromJSON(
    response_text,
    flatten = TRUE
  )

  if (!is.data.frame(data)) {
    stop(
      "Unexpected response from ", endpoint,
      ": expected a table of records."
    )
  }

  data
}


# Build an API filter for a nonempty vector of IDs.
# Stop rather than sending an invalid empty in.(...) query.
make_in_filter <- function(ids, field_name) {

  ids <- unique(ids[!is.na(ids)])

  if (length(ids) == 0) {
    stop(
      "Cannot query ", field_name,
      ": no IDs were available from the previous step."
    )
  }

  paste0(
    "in.(",
    paste(ids, collapse = ","),
    ")"
  )
}


# Check that an API response contains the columns needed downstream.
check_columns <- function(data, required_columns, step_name) {

  missing_columns <- setdiff(
    required_columns,
    names(data)
  )

  if (length(missing_columns) > 0) {
    stop(
      step_name,
      " is missing expected column(s): ",
      paste(missing_columns, collapse = ", "),
      ". Check the PREP API response."
    )
  }

  invisible(data)
}


################################################################################
# 3. Find sampling stations
################################################################################

stations <- map_dfr(
  STATION_CODES,
  function(station_code) {
    get_prep(
      "/samplingfeatures",
      list(
        samplingfeaturecode = paste0("eq.", station_code)
      )
    )
  }
)

check_columns(
  stations,
  c(
    "samplingfeatureid",
    "samplingfeaturecode",
    "samplingfeaturename"
  ),
  "Sampling stations"
)

stations <- stations %>%
  select(
    samplingfeatureid,
    samplingfeaturecode,
    samplingfeaturename
  ) %>%
  distinct()

missing_stations <- setdiff(
  STATION_CODES,
  stations$samplingfeaturecode
)

if (length(missing_stations) > 0) {
  stop(
    "The following requested station(s) were not found: ",
    paste(missing_stations, collapse = ", ")
  )
}

message("Sampling stations found: ", nrow(stations))


################################################################################
# 4. Find feature actions for stations
################################################################################

# Results are linked to stations through feature actions. First identify
# the actions associated with our stations, then use those action IDs to
# find the corresponding result series.

# Results are linked to sampling stations through feature actions.

featureactions <- map_dfr(
  stations$samplingfeatureid,
  function(station_id) {
    get_prep(
      "/featureactions",
      list(
        samplingfeatureid = paste0("eq.", station_id)
      )
    )
  }
)

check_columns(
  featureactions,
  c("featureactionid", "samplingfeatureid"),
  "Feature actions"
)

featureactions <- featureactions %>%
  distinct()

if (nrow(featureactions) == 0) {
  stop("No feature actions were found for the selected stations.")
}

message("Feature actions found: ", nrow(featureactions))


################################################################################
# 5. Find result series and variable metadata
################################################################################

results <- get_prep(
  "/results",
  list(
    featureactionid = make_in_filter(
      featureactions$featureactionid,
      "featureactionid"
    )
  )
)

check_columns(
  results,
  c("resultid", "featureactionid", "variableid"),
  "Results"
)

if (nrow(results) == 0) {
  stop("No result series were found for the selected feature actions.")
}

variables <- get_prep(
  "/variables",
  list(
    variableid = make_in_filter(
      results$variableid,
      "variableid"
    )
  )
)

check_columns(
  variables,
  c(
    "variableid",
    "variablecode",
    "variablenamecv",
    "variabledefinition"
  ),
  "Variable metadata"
)

results_with_variables <- results %>%
  left_join(
    variables %>%
      select(
        variableid,
        variablecode,
        variablenamecv,
        variabledefinition
      ),
    by = "variableid"
  )

target_results <- results_with_variables %>%
  filter(variablecode %in% VARIABLE_CODES)

if (nrow(target_results) == 0) {
  stop(
    "No result series matched the requested variables. ",
    "Check VARIABLE_CODES and the PREP API data."
  )
}

message(
  "Result series matching requested variables: ",
  n_distinct(target_results$resultid)
)


################################################################################
# 6. Add time-series metadata and filter aggregation type
################################################################################

timeseriesresults <- get_prep(
  "/timeseriesresults",
  list(
    resultid = make_in_filter(
      target_results$resultid,
      "resultid"
    )
  )
)

check_columns(
  timeseriesresults,
  c(
    "resultid",
    "aggregationstatisticcv",
    "zlocation",
    "zlocationunitsid"
  ),
  "Time-series metadata"
)

target_results <- target_results %>%
  left_join(
    timeseriesresults %>%
      select(
        resultid,
        aggregationstatisticcv,
        zlocation,
        zlocationunitsid
      ),
    by = "resultid"
  ) %>%
  filter(aggregationstatisticcv == "Continuous") # Filter for grab sample data

if (nrow(target_results) == 0) {
  stop(
    "No result series remained after filtering for ",
    "aggregationstatisticcv == 'Continuous'."
  )
}

# Add station information to each result series.
target_results <- target_results %>%
  left_join(
    featureactions %>%
      select(featureactionid, samplingfeatureid),
    by = "featureactionid"
  ) %>%
  left_join(
    stations,
    by = "samplingfeatureid"
  )

message(
  "Continuous result series retained: ",
  n_distinct(target_results$resultid)
)


################################################################################
# 7. Retrieve observations
################################################################################

result_ids <- unique(target_results$resultid)

values <- get_prep(
  "/timeseriesresultvalues",
  list(
    resultid = make_in_filter(
      result_ids,
      "resultid"
    )
  )
)

check_columns(
  values,
  c("resultid", "valuedatetime", "datavalue"),
  "Time-series result values"
)

if (nrow(values) == 0) {
  stop(
    "The API returned no observations for the selected result series."
  )
}

# Join observations to their result and station metadata.
raw_data <- values %>%
  left_join(
    target_results %>%
      select(
        resultid,
        samplingfeaturecode,
        samplingfeaturename,
        variablecode,
        variablenamecv,
        unitsid,
        aggregationstatisticcv,
        featureactionid
      ) %>%
      distinct(),
    by = "resultid"
  )

if (nrow(raw_data) == 0) {
  stop("No observations remained after joining result metadata.")
}

################################################################################
# 8. Save observations and retrieval metadata
################################################################################

write.csv(
  raw_data,
  RAW_DATA_FILE,
  row.names = FALSE,
  na = ""
)

retrieval_metadata <- data.frame(
  retrieved_at_utc = format(
    Sys.time(),
    tz = "UTC",
    format = "%Y-%m-%dT%H:%M:%SZ"
  ),
  api_base_url = BASE_URL,
  observation_rows = nrow(raw_data),
  result_series = n_distinct(raw_data$resultid),
  station_codes = paste(STATION_CODES, collapse = "; "),
  variable_codes = paste(VARIABLE_CODES, collapse = "; "),
  stringsAsFactors = FALSE
)

write.csv(
  retrieval_metadata,
  RETRIEVAL_LOG_FILE,
  row.names = FALSE,
  na = ""
)

message("Data retrieval complete.")
message("Observation rows saved: ", nrow(raw_data))
message("Raw data file: ", RAW_DATA_FILE)
message("Retrieval log: ", RETRIEVAL_LOG_FILE)
