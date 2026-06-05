# Website page generation

District pages are produced in two steps:

1. **`generate_pages.py`** writes a thin `.qmd` per district from
   `website/_gen/district_page.qmd`, filling in the office/district, the short
   description (summary), and a **data fingerprint**.
2. **`quarto render`** turns each `.qmd` into HTML under `../docs/`. The page's
   maps, demographics, and election tables are computed at render time by
   `legislative_info.R`, which loads everything from the published
   **ma-election-db** dataset (`https://bwbensonjr.github.io/ma-election-db/data/`).

Quarto runs with `execute: freeze: auto`, so a page is re-rendered only when its
`.qmd` source changes. The data fingerprint (a composite of the temporal keys
that drive the page — `pvi` / `election` / `census` / `redistricting` /
`summary`) is embedded in the `.qmd` precisely so that a change in the
underlying data changes the `.qmd` and triggers a re-render of just that
district.

## Changing a district's short description and rendering its page

The short description ("summary") lives in the **ma-election-db** repo, not
here. The end-to-end workflow spans both repos.

### 1. Edit the summary in ma-election-db

The source of truth is `data/district_summaries.csv` in the sibling
`ma-election-db` checkout. It is keyed by `(office, district, effective_date)`,
where `effective_date` is ISO `YYYY-MM-DD`. The summary in effect for a district
is the row with the most recent `effective_date` that is on or before today.

There are two ways to change it:

- **Correction** (fix wording, no need to preserve the old text): edit the
  `summary` cell of the existing row in place, leaving `effective_date` as-is.
- **Versioned update** (the district materially changed — redistricting,
  special election, new incumbent — and you want to keep the prior text): add a
  **new row** for that `(office, district)` with a later `effective_date` and
  the new summary. The newer row wins; the old one is preserved as history.

Either way the new text ends up embedded in the generated `.qmd`, so the page
will re-render.

`office` / `district` must use the canonical values, e.g. office
`U.S. House` with district `First` (ordinal words, not `1`), or
`State Representative` with `Sixth Middlesex`. (U.S. House and Governor's
Council districts are ordinal words here.)

### 2. Publish ma-election-db

mapoli reads the **published** CSV over HTTP, so the edit must be committed,
pushed, and deployed by GitHub Pages before mapoli will see it:

```bash
cd ../ma-election-db
git add data/district_summaries.csv
git commit -m "Update <office> <district> summary"
git push
# Optional: refresh the SQLite copy too (page generation does not need it)
#   Rscript build_sqlite.R
```

Wait for the GitHub Pages deploy to finish (usually under a minute) before the
next step — otherwise the generator will read the old text.

### 3. Regenerate that district's .qmd in mapoli

`--district` requires `--office`. Pass the canonical district name:

```bash
cd ../mapoli
uv run --project website python website/_gen/generate_pages.py \
    --office "U.S. House" --district "First"
```

This rewrites the single file
`website/districts/<office-slug>/<district-slug>.qmd` with the new description
and an updated fingerprint. `git diff` on that file should show the description
change (and possibly the `summary=` key in the fingerprint, if you used a new
`effective_date`).

The office slugs are `state-rep`, `state-senate`, `gov-council`, `us-house`.
The district slug is the district name lowercased, spaces → `-`, `&` → `and`,
commas removed (e.g. `First`, `sixth-middlesex`,
`barnstable-dukes-and-nantucket`).

### 4. Render the page to HTML

```bash
cd website
quarto render districts/us-house/first.qmd
```

Output is written to `../docs/districts/us-house/first.html` (per
`output-dir: ../docs` in `_quarto.yml`). Because the `.qmd` changed in step 3,
`freeze: auto` re-executes the page; an unchanged `.qmd` would be skipped.

Then commit the regenerated `.qmd` and the rendered output in mapoli:

```bash
cd ..
git add website/districts/us-house/first.qmd docs/districts/us-house/first.html
git commit -m "Re-render U.S. House First district page"
git push
```

## Regenerating everything

To regenerate all 217 `.qmd` files (e.g. after a dataset-wide change) and render
the whole site:

```bash
uv run --project website python website/_gen/generate_pages.py   # all districts
find website/districts -name "*.qmd" -exec quarto render {} \;    # freeze skips unchanged
```

Only the districts whose fingerprint changed will actually re-execute; the rest
are served from the Quarto freeze cache.
