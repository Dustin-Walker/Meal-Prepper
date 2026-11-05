# Spec Delta

## Purpose

Finds which items on a configured watchlist of grocery staples are currently on sale at one chosen Fred Meyer store, using the Kroger Public API, without exceeding the API's call limits.

## ADDED Requirements

### Requirement: Client-credentials authentication
The system SHALL get a Kroger API access token with the OAuth2 client-credentials grant and scope `product.compact`, reading the client ID and secret from Rails credentials. It SHALL reuse a token until it expires instead of requesting a new one for every call.

#### Scenario: Token obtained and reused
- **WHEN** a run makes several Kroger API calls within the token's lifetime
- **THEN** exactly one token request is made and every API call sends that token as a Bearer authorization header

#### Scenario: Missing credentials
- **WHEN** the Kroger client ID or secret is missing from Rails credentials
- **THEN** the run stops before any HTTP call, with an error that names the missing credential keys and says to run `bin/rails credentials:edit`

#### Scenario: Token request rejected
- **WHEN** the token endpoint returns a non-success status
- **THEN** the run stops with an error that includes the HTTP status and does not print the client secret

### Requirement: Store location lookup
The system SHALL provide a manually run lookup that lists Fred Meyer stores near a given ZIP code, showing each store's location ID, name, and address, so the user can choose one and save its ID in config.

#### Scenario: Listing nearby stores
- **WHEN** the user runs the location lookup with ZIP code 97005
- **THEN** the system lists only Fred Meyer stores returned by the Locations API near that ZIP, each with its location ID, name, and street address

#### Scenario: No stores found
- **WHEN** the Locations API returns no Fred Meyer stores for the ZIP code
- **THEN** the system reports that no stores were found and exits without error

### Requirement: Configured store is required
Sale-item searches SHALL use the store location ID from the sales-brief config file. If no location ID is set, the run SHALL stop before searching and point the user to the location lookup.

#### Scenario: Location ID missing
- **WHEN** the sales brief is run and the config has no store location ID
- **THEN** the run stops before any Products API call, with an error naming the config key and the location lookup command

### Requirement: Watchlist product search
The system SHALL search the Products API once for each term in the configured watchlist, filtered to the configured store location so that store-specific regular and promo prices are returned.

#### Scenario: Each term searched at the store
- **WHEN** the watchlist contains "chicken breast" and "broccoli"
- **THEN** the system makes one Products API search for each term, and every search includes the configured location ID as the location filter

#### Scenario: Watchlist is configurable
- **WHEN** the user adds a term to the watchlist in the config file
- **THEN** the next run searches for that term with no code change

### Requirement: Sale item detection
An item SHALL be considered on sale only when its promo price is greater than 0 and less than its regular price at the configured store. Items that are not on sale SHALL be dropped from the results.

#### Scenario: Promo below regular
- **WHEN** a product's regular price is 6.99 and its promo price is 4.99
- **THEN** the product is kept as a sale item with both prices recorded

#### Scenario: No promo
- **WHEN** a product's promo price is 0 or missing
- **THEN** the product is not treated as a sale item

#### Scenario: Promo equal to regular
- **WHEN** a product's promo price equals its regular price
- **THEN** the product is not treated as a sale item

#### Scenario: No price at the store
- **WHEN** a product has no price for the configured store
- **THEN** the product is not treated as a sale item

### Requirement: Sale item fields
Each sale item SHALL include the product ID, UPC, description, brand, size, regular price, promo price, and the watchlist term or terms that matched it.

#### Scenario: Sale item record
- **WHEN** a sale item is found
- **THEN** its record includes product ID, UPC, description, brand, size, regular price, promo price, and matched watchlist terms

### Requirement: Duplicate products merged
When more than one watchlist term returns the same product, the system SHALL keep that product once and record every term that matched it.

#### Scenario: Product matched by two terms
- **WHEN** the same product ID is returned by both "rice" and "brown rice"
- **THEN** the results contain that product once, with both terms listed as matches

### Requirement: Per-run API call budget
The system SHALL count every Kroger API call in a run, including token requests, and SHALL make no more calls once the configured per-run budget is reached. The budget SHALL default to a value far below Kroger's 10,000 calls/day limit.

#### Scenario: Budget reached
- **WHEN** the call budget is 5 and the watchlist has 10 terms
- **THEN** no more than 5 Kroger API calls are made, the run still writes output for the terms that were searched, and the output lists the terms that were skipped

#### Scenario: Normal run within budget
- **WHEN** the watchlist and page settings need fewer calls than the budget
- **THEN** every term is searched and no terms are listed as skipped

### Requirement: Search failures do not stop the run
If one watchlist term's search fails because of an HTTP error or timeout, the system SHALL record the failure for that term and keep searching the other terms.

#### Scenario: One term fails
- **WHEN** the search for "salmon" returns HTTP 500 and the other searches succeed
- **THEN** sale items from the other terms are still returned, and "salmon" is reported as a failed term with its error

#### Scenario: Rate limited
- **WHEN** a Kroger API call returns HTTP 429
- **THEN** the system stops making Kroger calls for the rest of the run, records the remaining terms as skipped because of rate limiting, and still writes output for the items found so far
