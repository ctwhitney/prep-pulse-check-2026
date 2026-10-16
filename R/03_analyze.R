
################################################################################
# 03_analyze.R
#
# Summarize water-quality measurements by station, variable, and year.
#
# The annual median describes the typical measurement for each year. The
# 25th and 75th percentiles show the spread of measurements within that year.
# These summaries are used to make the water-quality figures.
################################################################################

library(dplyr)

# Read the sampling events created by 02_clean_data.R
event_data <- read.csv(
  "data/processed/water_quality_events.csv",
  stringsAsFactors = FALSE
)

# Restore the date and year fields after reading the CSV
event_data <- event_data %>%
  mutate(
    Date = as.Date(Date),
    Year = as.integer(Year),
    datavalue = as.numeric(datavalue)
  )

# Summarize events within each station, variable, and year
annual_summary <- event_data %>%
  group_by(
    samplingfeaturecode,
    samplingfeaturename,
    analysis_variable,
    Year
  ) %>%
  summarise(
    n_events = n(),
    median_value = median(datavalue, na.rm = TRUE),
    q25 = quantile(datavalue, probs = 0.25, na.rm = TRUE),
    q75 = quantile(datavalue, probs = 0.75, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(samplingfeaturecode, analysis_variable, Year)

# Save the annual summaries for use in 04_make_figures.R
dir.create("data/processed", showWarnings = FALSE, recursive = TRUE)

write.csv(
  annual_summary,
  "data/processed/annual_water_quality_summary.csv",
  row.names = FALSE
)

# Quick checks
print(dim(annual_summary))

print(
  annual_summary %>%
    group_by(samplingfeaturecode, analysis_variable) %>%
    summarise(
      first_year = min(Year),
      last_year = max(Year),
      years_with_data = n(),
      min_events_per_year = min(n_events),
      median_events_per_year = median(n_events),
      .groups = "drop"
    )
)

print(
  summary(annual_summary$median_value)
)

print(file.exists("data/processed/annual_water_quality_summary.csv"))