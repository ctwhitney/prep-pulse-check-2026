# 04_make_figures.R

# Create eelgrass and water-quality figures for the 2026 science pulse.

library(dplyr)
library(tidyr)
library(ggplot2)
library(readr)

dir.create("figures", showWarnings = FALSE)


station_names <- c(
  "GRBGB" = "Great Bay Proper",
  "GRBUPR" = "Upper Piscataqua River",
  "GRBCML" = "Portsmouth Harbor"
)

station_levels <- c(
  "Great Bay Proper",
  "Upper Piscataqua River",
  "Portsmouth Harbor"
)

# ------------------------------------------------------------

# 1. Eelgrass coverage

# ------------------------------------------------------------

eelgrass_raw <- read_csv(
  "data/eelgrass_cover_data.csv",
  show_col_types = FALSE
)

eelgrass_long <- eelgrass_raw %>%
  select(
    Year,
    Great_Bay,
    Upper_Piscataqua_River,
    Portsmouth_Harbor
  ) %>%
  pivot_longer(
    cols = -Year,
    names_to = "Location",
    values_to = "Acres"
  ) %>%
  filter(!is.na(Acres)) %>%
  mutate(
    Location = recode(
      Location,
      Great_Bay = "Great Bay Proper",
      Upper_Piscataqua_River = "Upper Piscataqua River",
      Portsmouth_Harbor = "Portsmouth Harbor"
    ),
    Location = factor(
      Location,
      levels = station_levels
    )
  )

# Break lines across long gaps in the eelgrass time series.

eelgrass_long <- eelgrass_long %>%
  arrange(Location, Year) %>%
  group_by(Location) %>%
  mutate(
    line_group = cumsum(
      is.na(lag(Year)) | Year - lag(Year) > 3
    )
  ) %>%
  ungroup()

eelgrass_plot <- ggplot(
  filter(eelgrass_long, Year >= 1981),
  aes(x = Year, y = Acres)
) +
  geom_line(
    aes(group = interaction(Location, line_group)),
    linewidth = 0.6,
    color = "#416788"
  ) +
  geom_point(size = 2, color = "#416788") +
  facet_wrap(~Location, scales = "free_y") +
  scale_y_continuous(
    limits = c(0, NA),
    expand = expansion(mult = c(0, 0.05))
  ) +
  scale_x_continuous(
    breaks = seq(1980, 2025, by = 5)
  ) +
  labs(
    # title = "Eelgrass coverage across the estuary",
    x = NULL,
    y = "Mapped eelgrass coverage (acres)"
  ) +
  theme_bw(base_size = 12) +
  theme(
    strip.background = element_blank(),
    strip.text = element_text(face = "bold"),
    panel.grid.minor = element_blank(),
    axis.text.x = element_text(angle = 45, hjust = 1)
  )

ggsave(
  "figures/figure_01_eelgrass_coverage.png",
  eelgrass_plot,
  width = 10,
  height = 5.5,
  dpi = 300
)

# ------------------------------------------------------------

# 2. Light attenuation (Kd)

# ------------------------------------------------------------

kd_summary <- annual_summary %>%
  filter(analysis_variable == "Light Attenuation Coefficient") %>%
  mutate(
    Station = factor(
      recode(samplingfeaturecode, !!!station_names),
      levels = station_levels
    )
  )

# Break lines across gaps in monitoring.
kd_summary <- kd_summary %>%
  arrange(samplingfeaturecode, Year) %>%
  group_by(samplingfeaturecode) %>%
  mutate(
    line_group = cumsum(
      is.na(lag(Year)) | Year - lag(Year) > 2
    )
  ) %>%
  ungroup()

kd_plot <- ggplot(
  kd_summary,
  aes(x = Year, y = median_value, color = Station, fill = Station)
) +
  geom_ribbon(
    aes(group = interaction(samplingfeaturecode, line_group), ymin = q25, ymax = q75),
    alpha = 0.15,
    color = NA
  ) +
  geom_line(aes(group = interaction(samplingfeaturecode, line_group)), linewidth = 0.8) +
  geom_point(size = 1.8) +
  labs(
    # title = "Light attenuation varies across the estuary",
    # subtitle = "Annual medians and interquartile ranges",
    x = NULL,
    y = expression("Light attenuation coefficient (m"^{-1}*")"),
    color = NULL,
    fill = NULL
    # caption = "Shaded bands show the 25th–75th percentile range."
  ) +
  scale_x_continuous(breaks = seq(2000, 2025, by = 5)) +
  theme_bw(base_size = 12) +
  theme(
    legend.position = "bottom",
    panel.grid.minor = element_blank()
  )

ggsave(
  "figures/figure_02_light_attenuation.png",
  kd_plot,
  width = 9,
  height = 5.5,
  dpi = 300
)

# ------------------------------------------------------------
# 3. Total suspended solids and chlorophyll a
# ------------------------------------------------------------

support_summary <- annual_summary %>%
  filter(
    analysis_variable %in% c(
      "Solids, Suspended Total",
      "Chlorophyll a"
    )
  ) %>%
  mutate(
    Station = factor(
      recode(samplingfeaturecode, !!!station_names),
      levels = station_levels
    ),
    Variable = recode(
      analysis_variable,
      "Solids, Suspended Total" = "Total suspended solids",
      "Chlorophyll a" = "Chlorophyll a"
    )
  )

# Bold the panel labels while keeping the unit notation
# in the selected plotmath expressions.
support_labels <- c(
  "Total suspended solids" =
    'bold("Total suspended solids (" * mg ~ L^{-1} * ")")',
  "Chlorophyll a" =
    'bold("Chlorophyll a (" * mu * g ~ L^{-1} * ")")'
)

# Break lines across gaps in monitoring.
support_summary <- support_summary %>%
  arrange(samplingfeaturecode, Variable, Year) %>%
  group_by(samplingfeaturecode, Variable) %>%
  mutate(
    line_group = cumsum(
      is.na(lag(Year)) | Year - lag(Year) > 2
    )
  ) %>%
  ungroup()

support_plot <- ggplot(
  support_summary,
  aes(
    x = Year,
    y = median_value,
    color = Station,
    fill = Station
  )
) +
  geom_ribbon(
    aes(
      group = interaction(samplingfeaturecode, line_group),
      ymin = q25,
      ymax = q75
    ),
    alpha = 0.15,
    color = NA
  ) +
  geom_line(
    aes(group = interaction(samplingfeaturecode, line_group)),
    linewidth = 0.7
  ) +
  geom_point(size = 1.5) +
  facet_wrap(
    ~Variable,
    scales = "free_y",
    ncol = 1,
    labeller = as_labeller(
      support_labels,
      default = label_parsed
    )
  ) +
  labs(
    x = NULL,
    y = "Annual median",
    color = NULL,
    fill = NULL
  ) +
  scale_x_continuous(
    breaks = seq(2000, 2025, by = 5)
  ) +
  theme_bw(base_size = 12) +
  theme(
    legend.position = "bottom",
    strip.background = element_blank(),
    strip.text = element_text(face = "bold"),
    panel.grid.minor = element_blank()
  )

ggsave(
  "figures/figure_03_supporting_water_quality.png",
  support_plot,
  width = 9,
  height = 7,
  dpi = 300
)