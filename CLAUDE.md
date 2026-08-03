# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

mapoli is a Massachusetts Legislative District Atlas that provides interactive maps and demographic data for all 217 Massachusetts legislative districts. The project generates static and interactive web pages for State Representative, State Senate, Governor's Council, and U.S. House districts.

## Architecture

This is a multi-language data science project with the following main components:

- **R**: Data processing, demographic analysis, map generation, and statistical modeling
- **Python**: Data processing, web scraping, geospatial data management, and page generation
- **Quarto**: Document generation and website rendering
- **JavaScript/HTML**: Interactive maps and web components

### Key Directories

- `R/`: **Shared R modules** for working with Massachusetts legislative district data
- `demographics/`: R scripts for census data processing and demographic analysis
- `districts/`: Contains a definition list of Massachusetts election districts
- `gis/`: Geospatial data (GeoJSON, shapefiles) and conversion scripts
- `pvi/`: Partisan Voting Index calculations and political analysis
- `results/`: Election results data and analysis scripts
- `model/`: Statistical modeling of legislative elections
- `website/`: Quarto website source files and generated content
- `docs/`: Final rendered website (output directory)

## R API for District Data

The `R/` directory contains shared modules for working with Massachusetts legislative district data. These can be used from any R script in the repository.

### Quick Start

```r
library(here)
source(here("R/ma_district_data.R"))
source(here("R/ma_district_query.R"))

# Load all data at once
data <- load_all_district_data()

# Query a district
get_district_incumbent(data$district_info, "State Representative", "First Suffolk")
get_district_pvi(data$district_info, "State Senate", "First Middlesex")
```

### R Modules

| Module | Purpose |
|--------|---------|
| `R/ma_district_data.R` | Data loading functions |
| `R/ma_district_query.R` | Query and lookup functions |
| `R/district_utils.R` | District name formatting and conversion |
| `R/precinct_utils.R` | Precinct data manipulation |
| `R/pvi_utils.R` | PVI calculation utilities |
| `R/geo_utils.R` | Compass direction abbreviation |
| `pvi/ma_pvi_maps.R` | Precinct-level PVI mapping |

### Data Loading Functions (`ma_district_data.R`)

```r
# Load all data (convenience function)
data <- load_all_district_data()
# Returns: list with prec_dist, pvi, elections, summaries, district_info

# Load specific datasets
prec_dist <- load_precinct_districts()      # Precinct-to-district mapping
pvi <- load_district_pvi()                   # District PVI data
elections <- load_legislative_elections()   # Election history since 1990
summaries <- load_district_summaries()      # District text descriptions
primaries <- load_primary_2026_candidates() # Sept 1, 2026 primary candidates

# Build combined district info
district_info <- build_district_info()      # Joins elections + PVI + summaries

# Demographics and geometry
demographics <- load_office_demographics("State Representative")
district_demo <- load_district_demographics("State Senate", "First Middlesex")
geometry <- load_office_geometry("State Senate")  # Returns sf object
precinct_geom <- load_precinct_geometry()         # Returns sf object
```

### Query Functions (`ma_district_query.R`)

**District Information:**
```r
# Get info for a specific district
info <- get_district_info(district_info, "State Representative", "First Suffolk")
get_district_summary(district_info, office, district)      # Text description
get_district_display_name(district_info, office, district) # e.g., "1st Suffolk"
get_district_incumbent(district_info, office, district)    # Legislator name
get_district_pvi(district_info, office, district)          # e.g., "D+15"
get_district_pvi_n(district_info, office, district)        # Numeric PVI

# Get all districts for an office
districts <- get_office_districts(district_info, "State Senate")
```

**Election History:**
```r
# Get election history for a district
history <- get_district_election_history(elections, office, district)
latest <- get_district_latest_election(elections, office, district)
```

**Primary Election Queries:**
```r
# Contested primaries (more than one candidate of the same party)
contested <- get_contested_primaries(primaries)
# Returns: office, district, district_id, party, num_candidates

# Districts with a contested primary for one office, in district_id order
districts <- get_contested_primary_districts(primaries, "State Senate")

# All candidates in a district, both parties, Democrats first
cands <- get_district_primary_candidates(primaries, office, district)
```

Candidate rows carry `is_incumbent` and `incumbent_running` resolved upstream
in ma-election-db, so no name matching is needed here.

**Precinct Queries:**
```r
# Get precincts in a district
precincts <- get_district_precincts(prec_dist, office, district)
by_city <- get_district_precincts_by_city_town(prec_dist, office, district)

# Get districts serving a city/town
representation <- get_city_town_representation(prec_dist, "Boston")
districts_by_town <- get_city_town_districts(prec_dist, "State Representative")
```

**Geometry Queries:**
```r
# Get district geometry with info joined
geom <- get_office_geometry_with_info(office_geom, district_info, office)

# Build district boundary from precincts
dist_geom <- get_district_geometry(precinct_geom, prec_dist, office, district)
```

**Listing Functions:**
```r
list_offices()                              # All 4 legislative offices
list_districts(district_info, office)       # All districts for an office
list_city_towns(prec_dist)                  # All 351 MA municipalities
```

### Utility Functions

**District Name Formatting (`district_utils.R`):**
```r
fix_district("1st Bristol")                 # "First Bristol"
word_to_numeric_ordinal("First Bristol")    # "1st Bristol"
numeric_to_word_ordinal("1st Bristol")      # "First Bristol"
normalize_ampersand("Norfolk & Plymouth")   # "Norfolk and Plymouth"
office_slug("State Representative")         # "state-rep"
district_slug("First Bristol")              # "first-bristol"
office_column("State Representative")       # "State_Rep"
```

**PVI Calculations (`pvi_utils.R`):**
```r
dem_percent(dem_2024, gop_2024, dem_2020, gop_2020)  # Two-election average
pvi_string(15.3)                                     # "D+15"
add_pvi_24(df)                                       # Add PVI columns to data frame
add_calculations(df)                                 # Add all PVI and shift columns
```

### PVI Mapping Functions (`pvi/ma_pvi_maps.R`)

Interactive maps showing precinct-level Partisan Voting Index within legislative districts.

```r
library(here)
source(here("pvi/ma_pvi_maps.R"))

# Create interactive map of precinct-level PVI for a district
district_pvi_map("State Representative", "First Suffolk")
district_pvi_map("State Senate", "First Middlesex")
district_pvi_map("U.S. House", "Seventh")
district_pvi_map("Governor's Council", "Fourth")

# Load precinct geometry with PVI data (used internally)
prec_pvi <- load_precinct_pvi_data()
```

**Color Scheme:**
- Blue shading indicates Democratic lean (positive PVI)
- Red shading indicates Republican lean (negative PVI)
- White indicates EVEN (PVI near 0)
- Values beyond ±15 are clamped to darkest colors for better visibility of small differences

**Popup Information:**
- City/Town
- Precinct (e.g., "3-1" or "5")
- PVI (e.g., "D+15", "R+3", "EVEN")
- Harris 2024 vote total
- Trump 2024 vote total

### Example: Analyze a District

```r
library(here)
source(here("R/ma_district_data.R"))
source(here("R/ma_district_query.R"))

data <- load_all_district_data()

# Get First Suffolk info
office <- "State Representative"
district <- "First Suffolk"

cat("District:", get_district_display_name(data$district_info, office, district), "\n")
cat("Incumbent:", get_district_incumbent(data$district_info, office, district), "\n")
cat("PVI:", get_district_pvi(data$district_info, office, district), "\n")
cat("Summary:", get_district_summary(data$district_info, office, district), "\n")

# Get precincts
precincts <- get_district_precincts_by_city_town(data$prec_dist, office, district)
print(precincts)

# Get election history
history <- get_district_election_history(data$elections, office, district)
print(history |> select(election_date, display_winner, percent_winner))
```

### Example: Find City/Town Representation

```r
# What districts represent Boston?
boston_reps <- get_city_town_representation(data$prec_dist, "Boston")
print(boston_reps)

# Which State Rep districts include Brookline?
brookline_districts <- data$prec_dist |>
    filter(city_town == "Brookline") |>
    pull(State_Rep) |>
    unique()
print(brookline_districts)
```

## Common Development Commands

### Website Generation

The website generation process uses templates in `website/_gen/` and a Makefile-based workflow:

From the `website/` directory:
```bash
# Generate all .qmd files from templates (creates district and office pages)
make -f _Makefile generate_qmd_pages

# Render all generated .qmd files to HTML
make -f _Makefile render_html

# Or render entire website with Quarto (includes both generation and rendering)
quarto render

# Render specific pages
quarto render index.qmd
quarto render districts/state-rep/
```

#### Website Generation Architecture

The website uses a two-step template-based generation process:

1. **Template Processing** (`website/_gen/`):
   - `generate_pages.py`: Python script that creates .qmd files from templates
   - `district_page.qmd`: Template for individual district pages
   - `office_page.qmd`: Template for office summary pages  
   - `legislative_info.R`: R functions for maps, tables, and data processing

2. **Quarto Rendering**: Converts generated .qmd files to final HTML pages

#### Template System

- Templates use Python string formatting (`%(variable_name)s`) for parameter substitution
- `generate_pages.py` reads district data from `districts/ma_leg_dists_w_summary.csv`
- Each district gets its own .qmd file with populated parameters (office, district name, description, etc.)
- Office pages are generated for each legislative office type (State Rep, State Senate, etc.)

### District Page Generation
From the `districts/` directory:
```bash
# Generate all district pages
python generate_pages.py

# Generate pages for specific office
python generate_pages.py --office "State Representative"

# Generate single district page
python generate_pages.py --office "State Senate" --district "First Middlesex"

# Generate office summary pages using Makefile
make office_summaries
make state_rep_summary
make state_senate_summary
```

### Data Processing
From the `demographics/` directory:
```bash
# Generate demographic data
make generate_data
Rscript ma_census.R
```

From the `pvi/` directory:
```bash
# Calculate Partisan Voting Index
Rscript ma_pvi_2024.R
```

### Python Environment
The `districts/` directory uses uv for dependency management:
```bash
# Install dependencies
uv sync

# Run scripts with uv
uv run python generate_pages.py
```

## Data Sources and Dependencies

### R Dependencies
- Uses `renv` for package management at the **project root**
- Restore packages with `renv::restore()` from the project root
- Key packages: tidyverse, sf, tmap, gt, quarto, tidycensus, tigris, here

### Python Dependencies
- Defined in `districts/pyproject.toml`
- Key packages: pandas, langchain, html2text

### External Data Sources
- Census data via R census APIs
- Election results from Massachusetts Secretary of State
- GIS data from MassGIS
- Legislative district shapefiles

## Key Files for Understanding the System

### Shared R Modules
- `R/ma_district_data.R`: Data loading functions for districts, elections, demographics, geometry
- `R/ma_district_query.R`: Query functions for looking up district info, precincts, elections
- `R/district_utils.R`: District name formatting and conversion utilities
- `R/precinct_utils.R`: Precinct data manipulation utilities
- `R/pvi_utils.R`: PVI calculation functions
- `R/geo_utils.R`: Compass direction abbreviation utilities

### Website Generation
- `website/_quarto.yml`: Main website configuration
- `website/_Makefile`: Makefile for website generation workflow
- `website/_gen/generate_pages.py`: Python script that creates .qmd files from templates
- `website/_gen/district_page.qmd`: Template for individual district pages
- `website/_gen/office_page.qmd`: Template for office summary pages
- `website/_gen/legislative_info.R`: Website-specific gt tables and tmap maps (uses shared R modules)
- `website/primaries-2026.qmd`: Hand-maintained page listing contested September 1, 2026 primaries by office and district (not template-generated)

### Data Processing
- `districts/generate_pages.py`: Legacy district page generation logic (districts version)
- `districts/ma_leg_dists_w_summary.csv`: District data with summaries used by website generation
- `pvi/ma_legislative_district_pvi_2024.csv`: Current district PVI data
- `pvi/ma_pvi_2024.R`: PVI calculation script (uses shared R modules)
- `pvi/ma_pvi_maps.R`: Precinct-level PVI mapping functions

## Development Workflow

1. Update underlying data in respective directories (`demographics/`, `pvi/`, `results/`)
2. Generate district summaries and ensure `districts/ma_leg_dists_w_summary.csv` is current
3. Generate website pages using template system from `website/`:
   - Run `make -f _Makefile generate_qmd_pages` to create .qmd files from templates
   - Run `make -f _Makefile render_html` to render HTML, or use `quarto render` for full site
4. Final output appears in `docs/` directory for GitHub Pages hosting

### Code Organization

- **Shared R modules** (`R/`): Reusable functions for loading and querying district data
- **Website rendering** (`website/_gen/`): gt tables and tmap maps that use the shared modules
- **Data processing** (`pvi/`, `demographics/`): Scripts that generate underlying data files

## Testing and Quality Control

No formal test suite exists. Quality control relies on:
- Visual inspection of generated maps and data tables
- Validation of district boundaries and demographic data
- Cross-referencing with official sources

## Notes

- District names must be consistently formatted across all data sources
- The system processes 160 State Rep + 40 State Senate + 9 U.S. House + 8 Governor's Council = 217 total districts
- Geographic data uses Massachusetts State Plane coordinate system
- Website uses freeze mode in Quarto to cache expensive computations
