## Steps for Making the Visualizations

Want to explore the data behind PREP's 2026 Science Pulse figures or recreate the visualizations yourself? PREP has made the R scripts used to generate these figures available on GitHub. The workflow walks through retrieving water-quality observations, preparing the data, summarizing measurements by year, and creating the final figures.

You do not need prior experience with R to get started, although you will need to install a couple of free software tools. Follow the steps below to run the analysis on your own computer.

### Step 1: Visit the GitHub repository

Open the PREP Science Pulse 2026 repository on GitHub: **[PREP Science Pulse 2026 repository](https://github.com/ctwhitney/prep-pulse-check-2026)**.

The repository contains the R scripts, the eelgrass coverage data file used in the analysis, and the three finished figures. You can view the figures directly on GitHub without installing anything. To recreate them yourself, continue with the steps below.

### Step 2: Download the project

On the repository page:

1. Click the green **Code** button near the top of the page.
2. Select **Download ZIP** from the menu.
3. Once the download finishes, locate the ZIP file on your computer.
4. Extract or unzip the file. Choose a folder where you can easily find the project again, such as your Documents folder.

You now have a local copy of the project, including the scripts and the input data needed for the eelgrass figure.

### Step 3: Install R and RStudio

The visualizations are made using R, a free programming language commonly used for scientific data analysis and graphics. RStudio Desktop provides an interface that makes it easier to work with R scripts and manage a project.

If you do not already have them installed:

1. Visit the [R Project website](https://cran.r-project.org/) and download R for your operating system.
2. Follow the installation instructions.
3. Visit the [RStudio Desktop download page](https://posit.co/download/rstudio-desktop/) and install RStudio Desktop.

You will need both R and RStudio to follow the remaining steps.

### Step 4: Open the project in RStudio

Find the folder you extracted in Step 2. Inside it, locate the file named `prep-pulse-check-2026.Rproj` and double-click it.

This opens the project in RStudio. Using the project file helps RStudio work from the correct folder, allowing the scripts to locate their input files and save their outputs in the intended locations.

In RStudio, look for the **Files** pane. Open the `R` folder to find the four numbered scripts.

### Step 5: Install the required R packages

The scripts rely on several R packages that provide functions for retrieving data, organizing observations, calculating summaries, and creating plots.

In RStudio, find the **Console** pane, click after the prompt, and paste the following command:

```r
install.packages(c(
  "httr",
  "jsonlite",
  "dplyr",
  "purrr",
  "lubridate",
  "tidyr",
  "ggplot2",
  "readr"
))
```

Press Enter and wait for the installation to finish. You only need to install these packages once for your R installation, unless you later need to update or reinstall them.

### Step 6: Run the scripts in order

The workflow is divided into four scripts so each stage of the analysis can be followed separately. Open each script from the `R` folder and click **Source** in the script editor to run it. Wait for each script to finish before starting the next one.

**Script 1: `01_get_data.R` — Retrieve the water-quality data**

This script connects to PREP's data API and retrieves observations for three monitoring locations: Great Bay Proper, Portsmouth Harbor, and the Upper Piscataqua River. It retrieves the selected light attenuation, total suspended solids, and chlorophyll-a measurements, along with relevant metadata.

The script saves the retrieved observations and a retrieval log locally:

- `data/raw_water_quality_observations.csv`
- `data/raw_water_quality_retrieval.csv`

An internet connection is required, and the PREP data API must be available.

**Script 2: `02_clean_data.R` — Prepare the observations**

This script prepares the retrieved observations for analysis. It excludes records flagged as `"Bad"`, combines the two chlorophyll-a variable codes into a single analysis category, and groups measurements into sampling events. Records flagged `"Good"` and `"Unknown"` are retained.

Measurements are grouped by station, date, and analysis variable. A gap of **more than two minutes** between consecutive observations starts a new sampling event; gaps of two minutes or less remain within the same event. Measurements within each event are averaged, and information about the original records and their quality flags is retained.

The event-level dataset is saved locally to `data/processed/water_quality_events.csv`.

**Script 3: `03_analyze.R` — Calculate annual summaries**

This script summarizes sampling events by station, variable, and year. It calculates the annual median, the 25th and 75th percentiles, and the number of events contributing to each annual summary.

The annual summary is saved locally to `data/processed/annual_water_quality_summary.csv`. These statistics form the basis of the water-quality figures.

**Script 4: `04_make_figures.R` — Create the visualizations**

The final script reads the eelgrass coverage data and annual water-quality summaries, then generates three PNG images:

- `figures/figure_01_eelgrass_coverage.png`
- `figures/figure_02_light_attenuation.png`
- `figures/figure_03_supporting_water_quality.png`

Open the project's `figures` folder to view the images or use them in your own work.

The water-quality figures show annual medians, with shaded bands representing the middle 50% of measurements contributing to each annual summary. Lines are broken across longer gaps in monitoring rather than implying continuous observations where data are unavailable.

**Run the scripts in numerical order.** Scripts 2 and 3 depend on files generated by the preceding steps, and Script 4 requires both the eelgrass input file and the annual water-quality summary. The raw and processed water-quality CSV files are generated locally and are not included in the repository.

### Step 7: Explore the results

Once the final script finishes, you can open the PNG files to inspect the figures. You can also explore the R scripts to see how the data are retrieved, cleaned, summarized, and plotted.

The workflow can be rerun to retrieve the water-quality observations available through the PREP API at that time and regenerate the visualizations. Because the available data may change, newly generated figures may differ from the versions published in the 2026 Science Pulse.
### A note about the data

The water-quality observations and intermediate summaries generated by the scripts are stored locally and are not included as static downloads in the repository. This allows users to retrieve the available observations when they run the analysis rather than relying on a fixed snapshot. The eelgrass coverage CSV is provided as an input file in the project.

These visualizations summarize monitoring observations and are intended to help readers explore changes over time. Patterns in the figures are descriptive and should not be interpreted as formal statistical trend tests.

For questions about the monitoring data or the Science Pulse, consult PREP's published materials and data documentation.
