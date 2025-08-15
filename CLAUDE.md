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

- `demographics/`: R scripts for census data processing and demographic analysis
- `districts/`: Python scripts for district page generation and R scripts for legislative data
- `gis/`: Geospatial data (GeoJSON, shapefiles) and conversion scripts
- `pvi/`: Partisan Voting Index calculations and political analysis
- `results/`: Election results data and analysis scripts
- `model/`: Statistical modeling of legislative elections
- `website/`: Quarto website source files and generated content
- `docs/`: Final rendered website (output directory)

## Common Development Commands

### Website Generation
From the `website/` directory:
```bash
# Render entire website
quarto render

# Render specific pages
quarto render index.qmd
quarto render districts/state-rep/
```

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
- Uses `renv` for package management in `demographics/` directory
- Key packages: tidyverse, sf, tmap, gt, quarto

### Python Dependencies
- Defined in `districts/pyproject.toml`
- Key packages: pandas, langchain, html2text

### External Data Sources
- Census data via R census APIs
- Election results from Massachusetts Secretary of State
- GIS data from MassGIS
- Legislative district shapefiles

## Key Files for Understanding the System

- `website/_quarto.yml`: Main website configuration
- `districts/generate_pages.py`: District page generation logic
- `website/_gen/district_page.qmd`: District page template
- `website/_gen/office_page.qmd`: Office summary page template
- `districts/legislative_info.R`: Core R functions for data processing and visualization
- `pvi/ma_legislative_district_pvi_2024.csv`: Current district PVI data

## Development Workflow

1. Update underlying data in respective directories (`demographics/`, `pvi/`, `results/`)
2. Generate district pages using Python scripts in `districts/`
3. Render website using Quarto from `website/`
4. Final output appears in `docs/` directory for GitHub Pages hosting

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