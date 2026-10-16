################################################################################
# 02_clean_data.R
#
# Clean raw water-quality observations retrieved from the PREP API.
#
# This script:
#   1. Excludes observations flagged as Bad
#   2. Harmonizes the two chlorophyll variable codes for this analysis
#   3. Groups measurements into sampling events using a 2-minute gap rule
#   4. Averages measurements within each sampling event
#   5. Retains information about the source records and quality flags
#
# This script uses raw_data created by 01_get_data.R.
# Statistical analysis and figure creation are handled in later scripts.
################################################################################

# Load packages
library(dplyr)
library(lubridate)

################################################################################
# 1. Filter and prepare observations
################################################################################

# Read the raw observations saved by 01_get_data.R.
raw_data <- read.csv(
  file.path("data", "raw_water_quality_observations.csv"),
  stringsAsFactors = FALSE
)

# Exclude observations explicitly flagged as Bad.
# Good and Unknown quality flags are retained.
clean_data <- raw_data %>%
  filter(qualitycodecv != "Bad") %>%
  mutate(
    valuedatetime = ymd_hms(valuedatetime),
    datavalue = as.numeric(datavalue),
    Date = as.Date(valuedatetime),
    Year = year(valuedatetime)
  ) %>%
  filter(
    !is.na(valuedatetime),
    !is.na(datavalue),
    is.finite(datavalue)
  )

################################################################################
# 2. Harmonize chlorophyll variable codes
################################################################################

# Chlorophyll a is reported under two PREP variable codes, reflecting
# different analytical methods. The newer method does not correct for
# pheophytin. Based on confirmation from the laboratory, the two datasets
# are considered comparable for this analysis and are combined into a
# single analytical variable.
#
# The original variablecode is retained so the source method information
# remains available.

clean_data_harmonized <- clean_data %>%
  mutate(
    analysis_variable = case_when(
      variablecode %in% c(
        "Chlorophyll A, Corrected For Pheophytin",
        "Chlorophyll A, Uncorrected For Pheophytin"
      ) ~ "Chlorophyll a",
      TRUE ~ variablecode
    )
  )

################################################################################
# 3. Identify sampling events
################################################################################

# Multiple measurements collected close together may belong to the same
# sampling event. Following the existing PREP analysis approach, a new
# event begins when the gap between consecutive measurements is greater
# than 2 minutes.
#
# Events are identified separately for each station, analytical variable,
# and date. This allows the two chlorophyll codes to be combined while
# keeping unrelated variables separate.

EVENT_GAP_MINUTES <- 2

clean_data_events <- clean_data_harmonized %>%
  arrange(
    samplingfeaturecode,
    analysis_variable,
    Date,
    valuedatetime
  ) %>%
  group_by(
    samplingfeaturecode,
    analysis_variable,
    Date
  ) %>%
  mutate(
    time_diff_min = as.numeric(
      difftime(
        valuedatetime,
        lag(valuedatetime),
        units = "mins"
      )
    ),
    event = cumsum(
      coalesce(time_diff_min > EVENT_GAP_MINUTES, TRUE)
    )
  ) %>%
  ungroup()

################################################################################
# 4. Summarize measurements by sampling event
################################################################################

# Average measurements within each event to produce one observation per
# station, analytical variable, and sampling event.
#
# Retain the original variable codes, quality flags, and number of source
# result series to help document how each event was constructed.

clean_data_summarized <- clean_data_events %>%
  group_by(
    samplingfeaturecode,
    samplingfeaturename,
    analysis_variable,
    Date,
    event
  ) %>%
  summarise(
    event_start = min(valuedatetime),
    event_end = max(valuedatetime),
    event_duration_minutes = as.numeric(
      difftime(event_end, event_start, units = "mins")
    ),
    valuedatetime = event_start,
    Year = first(Year),
    datavalue = mean(datavalue),
    n_measurements = n(),
    n_result_series = n_distinct(resultid),
    source_variable_codes = paste(
      sort(unique(variablecode)),
      collapse = "; "
    ),
    quality_codes = paste(
      sort(unique(qualitycodecv)),
      collapse = "; "
    ),
    .groups = "drop"
  )

################################################################################
# 5. Check the cleaned data
################################################################################

# Count sampling events by station and analytical variable.
clean_data_summarized %>%
  count(samplingfeaturecode, analysis_variable)

# Check the number of events and their overall date range.
clean_data_summarized %>%
  summarise(
    n_events = n(),
    start_date = min(Date),
    end_date = max(Date)
  )

# Check how many measurements contributed to each event.
clean_data_summarized %>%
  count(n_measurements) %>%
  arrange(desc(n_measurements))

################################################################################
# 6. Save observations and retrieval metadata
################################################################################

# Save the event-level data for use in 03_analyze.R.
PROCESSED_DIR <- file.path("data", "processed")

dir.create(
  PROCESSED_DIR,
  recursive = TRUE,
  showWarnings = FALSE
)

EVENT_DATA_FILE <- file.path(
  PROCESSED_DIR,
  "water_quality_events.csv"
)

write.csv(
  clean_data_summarized,
  EVENT_DATA_FILE,
  row.names = FALSE,
  na = ""
)

message("Sampling events saved: ", nrow(clean_data_summarized))
message("Event-level data file: ", EVENT_DATA_FILE)
