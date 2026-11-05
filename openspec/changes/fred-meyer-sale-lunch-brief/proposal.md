# Proposal

## Why

Planning a week of meal-prep lunches around what's actually on sale at my local Fred Meyer means scrolling the store site item by item and copying prices and nutrition by hand. A manually run task that pulls current sale prices for a watchlist of lunch staples, adds nutrition facts, and writes a ready-to-paste brief would turn that into one command, so I can take the brief to Claude chat for lunch ideas.

## What Changes

- Add a Kroger Public API client (Fred Meyer is a Kroger banner): OAuth2 client-credentials token with scope `product.compact`, plus Locations and Products endpoints. Client ID and secret come from Rails credentials.
- Add a helper rake task that lists nearby Fred Meyer stores (Beaverton/Portland area) so I can pick a `locationId` and save it in config.
- Add a YAML config file holding the store `locationId`, a watchlist of lunch-staple search terms (chicken breast, ground turkey, salmon, lean beef, eggs, broccoli, frozen stir-fry vegetables, rice, Banza pasta, and so on), a per-run API call budget, and my lunch constraints.
- Search Products once per watchlist term, scoped to the configured store so `price.regular` and `price.promo` come back. Keep only items on sale, meaning `promo > 0` and `promo < regular`. Remove duplicate products found by more than one term.
- Enforce a per-run call budget well under Kroger's 10,000 calls/day limit. Kroger has no "all sales" endpoint, so the watchlist is the only way to find sale items.
- Look up each sale item's UPC on Open Food Facts for calories, protein, and sodium per serving. When there is no match or a value is missing, leave it blank and never estimate it.
- Add `bin/rails sales:brief`, which writes:
  - a JSON snapshot of the enriched sale items, and
  - a Markdown brief listing each sale item (regular vs. promo price, size, nutrition), followed by my lunch constraints and a request for 3 lunch ideas (not full recipes).
- Add WebMock as a test dependency. All HTTP in the test suite is stubbed, and no test calls a live API.

**Out of scope:** scheduling or recurring runs, calling the Claude API, the weekly ad, digital coupons, a web UI, and saving sale items to the database.

## Capabilities

### New Capabilities

- `grocery-sales/kroger-sale-items`: authenticating with the Kroger Public API, looking up store locations, searching the watchlist at the configured store, finding sale items, and staying within the call budget.
- `grocery-sales/nutrition-enrichment`: matching sale items to Open Food Facts by UPC and attaching per-serving calories, protein, and sodium. Missing data stays blank and is never estimated.
- `grocery-sales/lunch-brief`: the `sales:brief` task's outputs, meaning the JSON snapshot and the Markdown brief with its sale-item table, lunch constraints, and request to Claude.

### Modified Capabilities

None. There are no existing specs.

## Impact

- **New code** (in `environment/meal-prepper/`): plain Ruby service objects under `app/services/grocery_sales/`, rake tasks in `lib/tasks/sales.rake`, and config in `config/sales_brief.yml`.
- **Credentials:** a new `kroger.client_id` / `kroger.client_secret` entry in `config/credentials.yml.enc` (edited by the user with `bin/rails credentials:edit`).
- **Dependencies:** add the `webmock` gem to the `:test` group. HTTP calls use Ruby's standard library `Net::HTTP`, so no runtime gem is added.
- **External services:** Kroger Public API (`api.kroger.com`) and Open Food Facts (`world.openfoodfacts.org`). Both are called only when the task is run by hand.
- **Files written:** `storage/sales_briefs/` (already gitignored through `/storage/*`).
- **Database:** no schema changes.
