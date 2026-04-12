# Mapoli Website Data Input Analysis & Unified Dataset Plan

## Context

The mapoli website generates pages for 217 Massachusetts legislative districts. Its data inputs are scattered across 15 files in 5 directories, each with different formats, update cadences, and upstream sources. This plan catalogs every input and designs a consolidation into ma-election-db as a unified dataset.

---

## Part 1: Complete Inventory of Website Data Inputs

### 1. District Metadata

| File | Location | Key Columns | Used By |
|------|----------|-------------|---------|
| `ma_leg_dists_w_summary.csv` | `districts/` | office, district, district_id, legislator, party, city_town, percent, PVI, PVI_N, summary | `generate_pages.py`, `load_district_summaries()` |

This **master file** mixes static identity, current legislator info, PVI (duplicated from PVI files), AI-generated summaries, and pre-formatted HTML/Markdown links. It's a denormalized view that should be decomposed.

### 2. Partisan Voting Index (PVI)

| File | Location | Key Columns | Used By |
|------|----------|-------------|---------|
| `ma_legislative_district_pvi_2024.csv` | `pvi/` | office, district, district_display, PVI, PVI_N | `load_district_pvi()` |
| `ma_precincts_districts_pres_2024.csv` | `pvi/` | city_town, ward, precinct, State_Rep, State_Senate, US_House, Gov_Council, Biden_20, Trump_20, Clinton_16, Trump_16, Harris_24, Trump_24 | `load_precinct_districts()` |

The precinct file is the **richest single file** -- it maps every precinct to all 4 district types AND contains 3 cycles of presidential vote data.

**Temporal nature of PVI data:** PVI is recalculated every 4 years after each presidential election. The calculation uses a 2-election average (current + previous presidential election) compared against a national baseline (see `R/pvi_utils.R`). For 2024 PVI, this means averaging Harris/Trump 2024 with Biden/Trump 2020 results. Historical PVI vintages already exist in mapoli:

| PVI Year | Current Election | Previous Election | District Maps |
|----------|-----------------|-------------------|---------------|
| 2016 | Clinton/Trump 2016 | Obama/Romney 2012 | Pre-2021 redistricting |
| 2020 | Biden/Trump 2020 | Clinton/Trump 2016 | Pre-2021 redistricting |
| 2024 | Harris/Trump 2024 | Biden/Trump 2020 | Post-2021 redistricting |

Corresponding precinct-district files exist across cycles:
- `ma_precincts_districts_12_16_pres.csv` -- 2012 redistricting districts, 2012+2016 votes
- `ma_precincts_districts_16_20_pres.csv` -- 2012 redistricting districts, 2016+2020 votes
- `ma_precincts_districts_pres_2022.csv` -- 2021 redistricting districts, 2016+2020 votes
- `ma_precincts_districts_pres_2024.csv` -- 2021 redistricting districts, 2016+2020+2024 votes

The current file schema uses **candidate-named columns** (e.g., `Biden_20`, `Harris_24`), which embeds a specific election cycle into the schema. A unified dataset should use **generic column names** to support multiple PVI vintages cleanly.

### 3. Demographics (Census ACS 2022)

| File | Location | Used By |
|------|----------|---------|
| `ma_state_rep_demographics.csv` | `demographics/data/` | `load_office_demographics()` |
| `ma_state_senate_demographics.csv` | `demographics/data/` | (same) |
| `ma_gov_council_demographics.csv` | `demographics/data/` | (same) |
| `ma_us_house_demographics.csv` | `demographics/data/` | (same) |
| `ma_precinct_demographics.csv` | `demographics/data/` | `legislative_info.R` |

All 5 share the same ~100-column schema (race, income, education, ancestry, poverty, density). The 4 office-level files could be one file with an `office` column.

### 4. Geometry (GeoJSON)

| File | Location | Size | Used By |
|------|----------|------|---------|
| `house2021.geojson` | `gis/geojson/` | 2.8MB | `load_office_geometry("State Representative")` |
| `senate2021.geojson` | `gis/geojson/` | 2.1MB | `load_office_geometry("State Senate")` |
| `govcouncil2021.geojson` | `gis/geojson/` | 1.8MB | `load_office_geometry("Governor's Council")` |
| `congressma118.geojson` | `gis/geojson/` | 1.8MB | `load_office_geometry("U.S. House")` |
| `wards_pcts_subs_2022.geojson` | `gis/geojson/` | 7.5MB | `load_precinct_geometry()` |

### 5. Election History (Remote -- already from ma-election-db)

| Source | Format | Used By |
|--------|--------|---------|
| `bwbensonjr.github.io/ma-election-db/data/ma_general_election_summaries.csv.gz` | CSV.gz | `load_legislative_elections()` |

---

## Part 2: Data Flow

```
UPSTREAM SOURCES
├── MA Secretary of State API → results/*.csv → pvi/ma_pvi_2024.R
├── U.S. Census (ACS 2022)   → demographics/ma_census.R
├── MassGIS shapefiles        → gis/makegeojson.py
└── ma-election-db (GitHub Pages) ──────────────────────────┐
                                                             │
DERIVED FILES (14 local + 1 remote)                          │
├── pvi/ma_precincts_districts_pres_2024.csv                 │
├── pvi/ma_legislative_district_pvi_2024.csv                 │
├── demographics/data/ma_*_demographics.csv (5 files)        │
├── districts/ma_leg_dists_w_summary.csv                     │
├── gis/geojson/*.geojson (5 files)                          │
│                                                            │
WEBSITE GENERATION                                           │
├── generate_pages.py (reads master CSV → .qmd files)        │
└── legislative_info.R (loads ALL data at render time) ──────┘
```

---

## Part 3: Gaps in ma-election-db

ma-election-db currently provides election summaries, candidates, and a district lookup. It does NOT yet provide:

1. **Precinct-to-district mapping** (the core join table)
2. **Presidential vote totals by precinct** (for PVI)
3. **PVI data** (district-level and precinct-level)
4. **Demographics** (census-derived)
5. **District geometry** (GeoJSON boundaries)
6. **District summaries** (AI-generated text)

---

## Part 4: Proposed Unified Dataset Structure

### Directory layout in ma-election-db

```
data/
  # Existing (unchanged)
  ma_general_election_summaries.csv.gz
  ma_general_election_candidates.csv.gz
  ma_elections.sqlite
  ma_election_districts.csv
  ...

  # NEW: Precinct-district mapping (keyed by redistricting year)
  precinct_district/
    ma_precinct_district_2021.csv         # Post-2021 redistricting (current)
    ma_precinct_district_2011.csv         # Previous redistricting cycle

  # NEW: Precinct presidential votes (keyed by PVI year)
  precinct_presidential_vote/
    ma_precinct_presidential_vote_2024.csv  # 2024 PVI: Harris/Trump 2024 + Biden/Trump 2020
    ma_precinct_presidential_vote_2020.csv  # 2020 PVI: Biden/Trump 2020 + Clinton/Trump 2016
    ma_precinct_presidential_vote_2016.csv  # 2016 PVI: Clinton/Trump 2016 + Obama/Romney 2012

  # NEW: District PVI (keyed by PVI year)
  pvi/
    ma_district_pvi_2024.csv              # PVI for all 217 districts as of 2024
    ma_district_pvi_2020.csv              # PVI as of 2020 (pre-redistricting districts)

  # NEW: Demographics (gzipped for size)
  demographics/
    ma_district_demographics.csv.gz       # All offices in one file (217 rows)
    ma_precinct_demographics.csv.gz       # Precinct-level (~2400 rows)

  # NEW: Geometry (keyed by redistricting year)
  geometry/
    2021/                                 # Post-2021 redistricting
      state_rep.geojson
      state_senate.geojson
      gov_council.geojson
      us_house.geojson
      precinct.geojson

  # NEW: District summaries (extracted from master CSV)
  district_summaries.csv
```

### SQLite schema additions to `ma_elections.sqlite`

The schema is designed to be **temporally aware**: PVI and precinct-district mappings are keyed by year to support historical analysis and future updates without schema changes.

```sql
-- Precinct-to-district mapping, keyed by redistricting year
-- One row per precinct per redistricting cycle (~2400 rows per cycle)
CREATE TABLE precinct_district (
    redistricting_year INTEGER NOT NULL,  -- e.g., 2011, 2021
    city_town TEXT NOT NULL,
    ward TEXT,
    precinct TEXT NOT NULL,
    state_rep TEXT,
    state_senate TEXT,
    us_house TEXT,
    gov_council TEXT,
    PRIMARY KEY (redistricting_year, city_town, ward, precinct)
);

-- Precinct-level presidential votes for PVI calculation
-- Stores the two elections used in each PVI calculation cycle
-- PVI uses a 2-election average: dem_percent(current) + dem_percent(previous)
-- compared against the same national 2-election average baseline
CREATE TABLE precinct_presidential_vote (
    pvi_year INTEGER NOT NULL,            -- year of most recent presidential election
    redistricting_year INTEGER NOT NULL,   -- which district map these precincts belong to
    city_town TEXT NOT NULL,
    ward TEXT,
    precinct TEXT NOT NULL,
    dem_current REAL,                      -- Dem votes in the more recent election
    gop_current REAL,                      -- GOP votes in the more recent election
    current_year INTEGER,                  -- e.g., 2024
    dem_previous REAL,                     -- Dem votes in the earlier election
    gop_previous REAL,                     -- GOP votes in the earlier election
    previous_year INTEGER,                 -- e.g., 2020
    PRIMARY KEY (pvi_year, city_town, ward, precinct)
);

-- National baseline totals for PVI calculation
-- PVI = local_dem_pct(2-election avg) - national_dem_pct(2-election avg)
CREATE TABLE national_presidential_baseline (
    pvi_year INTEGER NOT NULL PRIMARY KEY, -- e.g., 2024
    dem_current INTEGER,                   -- e.g., Harris 2024 national total
    gop_current INTEGER,                   -- e.g., Trump 2024 national total
    current_year INTEGER,                  -- e.g., 2024
    dem_previous INTEGER,                  -- e.g., Biden 2020 national total
    gop_previous INTEGER,                  -- e.g., Trump 2020 national total
    previous_year INTEGER                  -- e.g., 2020
);

-- District PVI, keyed by PVI year (217 rows per cycle)
CREATE TABLE district_pvi (
    pvi_year INTEGER NOT NULL,            -- e.g., 2024, 2020
    office TEXT NOT NULL,
    district TEXT NOT NULL,
    district_display TEXT,
    pvi TEXT,                              -- "D+15", "R+3", "EVEN"
    pvi_n REAL,                            -- numeric, positive = D lean
    PRIMARY KEY (pvi_year, office, district)
);

-- District demographics -- all offices in one table (217 rows per census vintage)
CREATE TABLE district_demographics (
    census_year INTEGER NOT NULL,          -- e.g., 2020 (decennial) or ACS vintage year
    office TEXT NOT NULL,
    district TEXT NOT NULL,
    total_population REAL,
    race_white_pct REAL, race_black_pct REAL, race_asian_pct REAL,
    race_hispanic_pct REAL, race_minority_pct REAL,
    median_age REAL, median_household_income REAL,
    ed_college_degree_pct REAL, below_poverty_pct REAL,
    wwc_pct REAL, area_m2 REAL, density_type TEXT,
    -- ... full ~100 columns preserved
    PRIMARY KEY (census_year, office, district)
);

-- Precinct demographics (~2400 rows per census vintage)
CREATE TABLE precinct_demographics (
    census_year INTEGER NOT NULL,
    city_town TEXT NOT NULL,
    ward TEXT,
    precinct TEXT NOT NULL,
    total_population REAL,
    -- ... same demographic columns
    PRIMARY KEY (census_year, city_town, ward, precinct)
);

-- District summaries (217 rows)
CREATE TABLE district_summary (
    office TEXT NOT NULL,
    district TEXT NOT NULL,
    summary TEXT,
    PRIMARY KEY (office, district)
);

-- Dataset versioning
CREATE TABLE dataset_metadata (
    dataset TEXT PRIMARY KEY,
    version TEXT,
    updated_date TEXT,
    source TEXT
);
```

### Key design decisions

**Temporal keys throughout:** Every table that changes over time has an explicit year key (`pvi_year`, `redistricting_year`, `census_year`). This means:
- Adding 2028 PVI data is just inserting new rows, not altering the schema
- Historical PVI can be queried for trend analysis (e.g., how a district's lean shifted from 2020 to 2024)
- Redistricting transitions are explicit -- the same precinct may map to different districts in different cycles

**Generic vote columns instead of candidate names:** The `precinct_presidential_vote` table uses `dem_current`/`gop_current`/`dem_previous`/`gop_previous` with corresponding year columns, rather than `harris_24`/`trump_24`/`biden_20`/`trump_20`. This means:
- The schema doesn't change every 4 years
- Adding 2028 data follows the same pattern
- The `current_year` and `previous_year` columns allow identifying which elections were used

**Separate precinct-district mapping from presidential votes:** The current mapoli files combine these into one file. Separating them reflects their different update cadences -- district assignments change with redistricting (~10 years), while presidential vote data arrives every 4 years. The tables join on `(city_town, ward, precinct)` and the `precinct_presidential_vote` table carries a `redistricting_year` FK to indicate which district map applies.

**National baseline table:** The PVI calculation requires national vote totals (currently hardcoded in `R/pvi_utils.R`). Storing these in a table makes the calculation fully reproducible from the database alone and avoids hardcoding constants that change every cycle.

**Demographics consolidated to one file per level:** The 4 office-level demographics CSVs become a single `ma_district_demographics.csv.gz` with an `office` column. This eliminates redundant file structure and makes it easy to query across office types.

### Why geometry stays as GeoJSON (not in SQLite)

- SpatiaLite requires native extensions, breaking the sqlime.org playground
- R/sf reads GeoJSON natively
- Total is only ~16MB, well within GitHub Pages limits
- Files change once per decade (redistricting)

---

## Part 5: Handling the Master CSV

`districts/ma_leg_dists_w_summary.csv` is a denormalized view. Its columns decompose as:

| Column(s) | True Source | After Consolidation |
|-----------|------------|-------------------|
| office, district, district_id | `ma_election_districts.csv` | Already in ma-election-db |
| legislator, party, city_town, percent | Latest election winner | Derivable from `general_election` table |
| PVI, PVI_N | `ma_legislative_district_pvi_2024.csv` | New `district_pvi` table |
| summary | AI-generated text | New `district_summary` table |
| district_md_ref, district_web_ref | Formatting for mapoli | Generated at build time by mapoli |

After consolidation, this file becomes a **generated artifact** rather than a primary data source. `generate_pages.py` would derive it from the unified dataset, or be rewritten to query ma-election-db directly.

---

## Part 6: Update Cadences and Temporal Model

| Dataset | Trigger | Cycle | Year Key |
|---------|---------|-------|----------|
| Elections | New results | Every 2 years + specials | election_date |
| Presidential votes | New presidential election | Every 4 years | `pvi_year` |
| District PVI | New presidential election | Every 4 years | `pvi_year` |
| Precinct-district mapping | Redistricting | Every 10 years | `redistricting_year` |
| District geometry | Redistricting | Every 10 years | `redistricting_year` |
| Demographics | ACS data release | Annual (5-year estimates) | `census_year` |
| Summaries | Manual/LLM update | As needed | (none) |

**How the temporal keys interact:**

After the 2028 presidential election, a new PVI cycle begins:
- New rows in `precinct_presidential_vote` with `pvi_year=2028`, using 2028 + 2024 results
- New rows in `district_pvi` with `pvi_year=2028`
- The `redistricting_year` stays at 2021 until the next redistricting (~2031)
- The `precinct_district` table is unchanged

After the next redistricting (~2031):
- New rows in `precinct_district` with `redistricting_year=2031`
- New geometry files in `geometry/2031/`
- Future PVI calculations will reference `redistricting_year=2031`
- Historical data with `redistricting_year=2021` is preserved for analysis

---

## Part 7: Where Should Data Processing Live?

A key architectural question: should ma-election-db just **store** unified data, or should it also **run** the processing pipelines that produce it?

### Current processing pipelines

| Pipeline | Script | Inputs | Shared R Code? | Self-Contained? |
|----------|--------|--------|----------------|-----------------|
| Election extraction | `ma-election-db/election_stats.py` | MA state API | No | Very high |
| Election summarization | `ma-election-db/elections.R` | Raw CSVs from above | No | Very high |
| GIS conversion | `mapoli/gis/makegeojson.py` | Local shapefiles | No | High |
| Demographics | `mapoli/demographics/ma_census.R` | Census API + GeoJSON files | No | Medium |
| Precinct results | `mapoli/results/ma_results.py` | MA state API + ma-election-db | No | Medium |
| PVI calculation | `mapoli/pvi/ma_pvi_2024.R` | Precinct results + prior-cycle data | Yes (5 files in `R/`) | Low |

### Option A: ma-election-db = data warehouse only

```
mapoli (processing + presentation)          ma-election-db (storage + serving)
├── pvi/ma_pvi_2024.R ─── computes ──────→  data/pvi/*.csv
├── demographics/ma_census.R ─ computes ──→  data/demographics/*.csv.gz
├── gis/makegeojson.py ─── converts ──────→  data/geometry/*.geojson
├── results/ma_results.py ─ fetches ──────→  data/precinct_presidential_vote/*.csv
│                                            data/ma_elections.sqlite (expanded)
│                                            ↓
└── website/ ← loads all data from ──────── GitHub Pages URLs
```

**Pros:** Minimal disruption. No R infrastructure needed in ma-election-db beyond what exists. Mapoli stays the "workbench" where data science happens.

**Cons:** Two repos must coordinate. Pushing outputs to ma-election-db is a manual step. Processing logic is separate from the data it produces.

### Option B: ma-election-db = data warehouse + all processing

```
ma-election-db (processing + storage + serving)
├── extract/election_stats.py               # existing
├── extract/ma_results.py                   # moved from mapoli/results/
├── process/elections.R                     # existing
├── process/ma_pvi.R                        # moved from mapoli/pvi/
├── process/ma_census.R                     # moved from mapoli/demographics/
├── process/makegeojson.py                  # moved from mapoli/gis/
├── R/                                      # shared R utilities (moved from mapoli/R/)
│   ├── pvi_utils.R
│   ├── precinct_utils.R
│   ├── district_utils.R
│   ├── geo_utils.R
│   └── ...
├── data/                                   # all outputs published via GitHub Pages
│   ├── pvi/, demographics/, geometry/, ... 
│   └── ma_elections.sqlite
│
mapoli (presentation only)
└── website/ ← loads all data from ──────── GitHub Pages URLs
```

**Pros:** Single source of truth for both data and the code that produces it. `make all` in one repo rebuilds everything. Cleaner separation: ma-election-db = data, mapoli = website.

**Cons:** Requires R infrastructure in ma-election-db (currently only `elections.R` uses R). The shared `R/` utilities would need to move. PVI calculation is tightly coupled to mapoli's precinct utilities. Larger, more complex repo.

### Option C: Hybrid -- move self-contained pipelines, keep complex ones

```
ma-election-db (extraction + storage + simple processing)
├── extract/election_stats.py               # existing
├── extract/ma_results.py                   # moved from mapoli/results/
├── process/elections.R                     # existing
├── gis/makegeojson.py                      # moved from mapoli/gis/
├── data/                                   # published via GitHub Pages
│
mapoli (complex processing + presentation)
├── R/                                      # shared R utilities stay here
├── pvi/ma_pvi_2024.R                       # stays (heavy R/ dependencies)
├── demographics/ma_census.R                # stays (depends on GeoJSON)
├── website/ ← loads from mix of local + GitHub Pages
```

**Pros:** Moves what's easy (GIS, precinct results) without the pain of moving PVI and its R utility chain. Pragmatic first step.

**Cons:** Still split across two repos. Demographics depends on GeoJSON, which has moved.

### Recommendation

**Start with Option A** (warehouse only) for the initial unification. The priority is getting a unified dataset published, not reorganizing processing code. Once the data schema is stable and proven, migrate toward **Option B** incrementally -- starting with the self-contained pipelines (GIS, precinct results) and deferring PVI until the R infrastructure is in place.

---

## Part 8: Implementation Phases (assuming Option A initially)

**Phase 1 -- Precinct-district mapping + presidential votes** (foundation)
- Create `precinct_district` table with `redistricting_year` key
  - Load existing data for 2021 redistricting cycle (from `ma_precincts_districts_pres_2024.csv`)
  - Optionally load 2011 redistricting cycle (from `ma_precincts_districts_16_20_pres.csv`)
- Create `precinct_presidential_vote` table with generic columns
  - Transform `Harris_24`/`Trump_24`/`Biden_20`/`Trump_20` into `dem_current`/`gop_current`/`dem_previous`/`gop_previous` with `pvi_year=2024`
  - Transform older files similarly for `pvi_year=2020` and `pvi_year=2016`
- Create `national_presidential_baseline` table (move hardcoded values from `R/pvi_utils.R`)
- Publish CSVs to `data/precinct_district/` and `data/precinct_presidential_vote/`

**Phase 2 -- District PVI**
- Create `district_pvi` table with `pvi_year` key
- Load 2024 PVI from `ma_legislative_district_pvi_2024.csv`
- Optionally calculate and load 2020 PVI for historical districts
- Update mapoli `R/ma_district_data.R` to load from remote URL (filtering by latest `pvi_year`)

**Phase 3 -- Demographics**
- Consolidate 4 office-level CSVs into single `ma_district_demographics.csv.gz` with `office` column
- Add `district_demographics` and `precinct_demographics` tables to SQLite
- Update mapoli loading functions

**Phase 4 -- Geometry**
- Copy 5 GeoJSON files into `data/geometry/2021/` (organized by redistricting year)
- Keep local copies in mapoli for build performance (they're stable)

**Phase 5 -- District summaries + eliminate master CSV**
- Extract summaries into `data/district_summaries.csv`
- Make `ma_leg_dists_w_summary.csv` a generated artifact
- Update `generate_pages.py`

**Phase 6 -- Build automation**
- Add `download_data` target to mapoli Makefile
- Update ma-election-db build scripts to produce all new tables
- Update mapoli `R/pvi_utils.R` to read national baselines from DB instead of hardcoding
- Document the unified dataset

---

## Part 9: Risks

| Risk | Mitigation |
|------|-----------|
| GeoJSON bloats git history | Changes once/decade; 16MB is acceptable |
| Remote loading slows website build | Local cache for geometry; CSV.gz loads fast over HTTP |
| Demographics = scope creep for "election-db" | Rename concept to "MA district data" or accept broader scope |
| Breaking mapoli during migration | Phase the work; old local files coexist temporarily |
| SQLite DB grows large | ~10MB total is well within sqlime.org limits |
| Temporal schema adds query complexity | Mapoli loading functions default to latest `pvi_year`/`redistricting_year`; historical queries are opt-in |
| Fractional precinct votes (split precincts) | Already present in source data; preserved as REAL columns |
| Backfilling historical PVI vintages | Start with 2024 only; add 2020/2016 incrementally as time permits |

---

## Part 10: Critical Files

**ma-election-db:**
- `elections.R` -- builds SQLite DB; needs new table-writing code
- `CLAUDE.md` -- must document new tables and structure

**mapoli:**
- `R/ma_district_data.R` -- all data loading; update URLs from local to remote
- `website/_gen/generate_pages.py` -- reads master CSV; update to use unified sources
- `districts/ma_leg_dists_w_summary.csv` -- to be decomposed/generated
