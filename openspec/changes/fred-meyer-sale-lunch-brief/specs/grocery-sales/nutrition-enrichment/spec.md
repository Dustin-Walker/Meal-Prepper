# Spec Delta

## Purpose

Adds per-serving calories, protein, and sodium to sale items by matching each item's UPC on Open Food Facts. Values are reported only when a source provides them and are never estimated.

## ADDED Requirements

### Requirement: UPC lookup on Open Food Facts
The system SHALL look up each sale item on Open Food Facts using the item's UPC. Because Kroger UPCs are zero-padded and leave out the check digit, it SHALL also try the standard barcode forms derived from that UPC until one matches.

#### Scenario: Match on a derived barcode
- **WHEN** a sale item's Kroger UPC is "0001111041700" and Open Food Facts knows the product only by its 12-digit UPC-A barcode with check digit
- **THEN** the item is matched to that Open Food Facts product

#### Scenario: Item without a UPC
- **WHEN** a sale item has no UPC
- **THEN** no lookup is made and the item's nutrition is left blank

### Requirement: Per-serving nutrition fields
On a match, the system SHALL record calories (kcal), protein (g), and sodium (mg) per serving, plus the serving size text, exactly as given by Open Food Facts. Sodium given in grams SHALL be converted to milligrams.

#### Scenario: Full nutrition available
- **WHEN** the matched product lists 120 kcal, 26 g protein, and 0.07 g sodium per serving, with serving size "112 g"
- **THEN** the item's nutrition is recorded as 120 calories, 26 g protein, 70 mg sodium, and serving size "112 g"

### Requirement: Missing nutrition is never estimated
If there is no match, or a matched product lacks a per-serving value, the system SHALL leave that value blank. It SHALL NOT estimate, infer, or calculate per-serving values from per-100g data or similar products.

#### Scenario: No match
- **WHEN** Open Food Facts has no product for any barcode form of the item's UPC
- **THEN** calories, protein, and sodium are all blank and the item is marked as having no nutrition match

#### Scenario: Partial data
- **WHEN** the matched product lists per-serving protein but no per-serving sodium
- **THEN** protein is recorded and sodium is blank

#### Scenario: Only per-100g data
- **WHEN** the matched product has per-100g values but no per-serving values
- **THEN** calories, protein, and sodium are all blank

### Requirement: Enrichment failures do not stop the run
If an Open Food Facts lookup fails because of an HTTP error or timeout, the system SHALL leave that item's nutrition blank, record the failure, and continue with the remaining items.

#### Scenario: Lookup times out
- **WHEN** the Open Food Facts lookup for one item times out
- **THEN** that item's nutrition is blank, the failure is recorded, and the other items are still enriched

### Requirement: Identifying client
Requests to Open Food Facts SHALL send a User-Agent header that names the application, as Open Food Facts asks of API clients, and SHALL NOT include personal contact details unless the user configures them.

#### Scenario: Request headers
- **WHEN** a lookup request is sent to Open Food Facts
- **THEN** the request carries a User-Agent naming the Meal Prepper application
