# Spec Delta

## Purpose

Produces, on demand, a JSON snapshot of the week's enriched sale items and a Markdown brief the user can paste into Claude chat to plan meal-prep lunches around those sales.

## ADDED Requirements

### Requirement: Manually run brief task
The system SHALL provide a manually run command, `bin/rails sales:brief`, that fetches sale items, enriches them with nutrition, and writes both a JSON snapshot and a Markdown brief. It SHALL NOT run on a schedule or call any AI service.

#### Scenario: Successful run
- **WHEN** the user runs `bin/rails sales:brief` with valid credentials and a configured store
- **THEN** a JSON snapshot and a Markdown brief are written, and the command prints the path of each file and the number of sale items found

### Requirement: Output location and naming
Both output files SHALL be written to `storage/sales_briefs/` and named with the run date, so an earlier run's files are kept. A second run on the same date SHALL overwrite that date's files.

#### Scenario: Dated files
- **WHEN** the brief is run on 2026-11-04
- **THEN** the files `storage/sales_briefs/2026-11-04.json` and `storage/sales_briefs/2026-11-04.md` exist

### Requirement: JSON snapshot contents
The JSON snapshot SHALL include the run timestamp, the store location ID, and every sale item with its prices, size, UPC, matched terms, and nutrition (blank values as null). It SHALL also include the terms that failed or were skipped, and the number of API calls made.

#### Scenario: Snapshot fields
- **WHEN** the snapshot is written
- **THEN** it has the run timestamp, location ID, an array of sale items with prices, size, UPC, matched terms, and nutrition, the failed and skipped terms, and the API call count

#### Scenario: Missing nutrition in snapshot
- **WHEN** a sale item has no nutrition match
- **THEN** its calories, protein, and sodium are null in the snapshot, not 0

### Requirement: Brief sale-item listing
The Markdown brief SHALL list every sale item with its description, brand, size, regular price, promo price, savings, and per-serving calories, protein, and sodium. Blank nutrition SHALL be shown as "n/a", never as 0.

#### Scenario: Item row
- **WHEN** a sale item has regular 6.99, promo 4.99, size "1 lb", and 120 kcal / 26 g protein / 70 mg sodium per serving
- **THEN** the brief shows that item with $6.99 regular, $4.99 promo, $2.00 savings, size "1 lb", and those nutrition values

#### Scenario: Item without nutrition
- **WHEN** a sale item has no nutrition data
- **THEN** its calories, protein, and sodium are shown as "n/a"

### Requirement: Brief lunch constraints
After the sale items, the brief SHALL state the user's lunch constraints, read from config: 4 servings (the same lunch Monday through Thursday), 500–700 calories, 40–45 g protein, and under about 600 mg sodium per serving, microwave-reheatable, whole or minimally processed ingredients, and frozen vegetables for volume.

#### Scenario: Default constraints
- **WHEN** the brief is generated with the default config
- **THEN** it states 4 servings for Monday through Thursday, 500–700 calories, 40–45 g protein, under ~600 mg sodium per serving, microwave-reheatable, whole/minimally processed ingredients, and frozen vegetables for volume

#### Scenario: Constraint changed in config
- **WHEN** the user changes the protein target in config to 35–40 g
- **THEN** the next brief states 35–40 g protein

### Requirement: Brief request to Claude
The brief SHALL end by asking for 3 lunch ideas that use the sale items and meet the constraints, and SHALL say that full recipes are not wanted yet.

#### Scenario: Closing request
- **WHEN** the brief is generated
- **THEN** its last section asks for 3 lunch ideas built from the listed sale items within the stated constraints, and says not to give full recipes yet

### Requirement: Brief reports gaps
If any watchlist terms failed or were skipped, or no sale items were found, the brief SHALL say so, so the reader knows the list may be incomplete.

#### Scenario: Skipped terms noted
- **WHEN** the terms "salmon" and "eggs" were skipped because of the call budget
- **THEN** the brief includes a note naming "salmon" and "eggs" as not searched

#### Scenario: No sale items
- **WHEN** no watchlist item is on sale
- **THEN** the files are still written and the brief says that no watchlist items are on sale this week
