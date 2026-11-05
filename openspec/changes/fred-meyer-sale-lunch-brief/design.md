# Design

## Context

The Rails app (`environment/meal-prepper/`) currently has only scaffolded models (Recipe, Ingredient, Tag, and so on). It has no `app/services/`, no rake tasks, no HTTP client gem, and no HTTP stubbing in tests. `config.autoload_lib(ignore: %w[assets tasks])` is set, and `/storage/*` and `/tmp/*` are gitignored. The suite is Minitest with `parallelize(workers: :number_of_processors)`. For motivation see proposal.md (Why); for behavior see the specs under `specs/grocery-sales/`.

Kroger Public API facts this design relies on:
- Token: `POST https://api.kroger.com/v1/connect/oauth2/token`, Basic auth with `client_id:client_secret`, body `grant_type=client_credentials&scope=product.compact`. Returns `access_token` and `expires_in` (about 1800 s).
- Locations: `GET /v1/locations?filter.zipCode.near=<zip>&filter.limit=<n>`. Each result has `locationId`, `chain`, `name`, and `address`.
- Products: `GET /v1/products?filter.term=<term>&filter.locationId=<id>&filter.limit=<≤50>&filter.start=<offset>`. Each item has `productId`, `upc`, `description`, `brand`, and `items[]`. `items[0].price.regular` / `.promo` and `items[0].size` appear only when a location is given.
- 10,000 product calls/day. There is no "on sale" filter.

## Goals / Non-Goals

**Goals:**
- Small, testable plain-Ruby objects, each with one job (auth/HTTP, search, enrichment, rendering), connected by one orchestrator that the rake task calls.
- Deterministic tests: all HTTP stubbed with WebMock and the clock frozen for dated filenames.
- No new runtime gems.

**Non-Goals:**
- Saving sale items to the database or linking them to the `Ingredient` model.
- Caching Open Food Facts results across runs. Revisit if lookups get slow.
- Concurrency. Calls are sequential, which is fine for about 15 terms and a few dozen sale items.

## Decisions

### Module layout under `app/services/grocery_sales/`
```
GrocerySales::KrogerClient      # token + GET helpers, call counting, budget, error mapping
GrocerySales::SaleItemFinder    # watchlist loop → SaleItem list + failed/skipped terms
GrocerySales::SaleItem          # Data.define value object (prices, size, upc, terms, nutrition)
GrocerySales::UpcCandidates     # Kroger UPC → ordered barcode candidates
GrocerySales::NutritionLookup   # Open Food Facts lookup → Nutrition (or blank)
GrocerySales::BriefRenderer     # SaleItems + constraints → Markdown string
GrocerySales::BriefRun          # orchestrates; writes JSON + MD; returns result paths
GrocerySales::Config            # wraps Rails.application.config_for(:sales_brief)
```
`app/services/` is autoloaded by Rails with no extra config. Putting this code in `lib/` was also considered. It was not chosen because `app/` is reloaded in development and keeps all app code in one conventional place.

### HTTP with `Net::HTTP`, wrapped once
Each client gets a small private `request` helper that sets timeouts (open 5 s, read 10 s), parses JSON, and raises typed errors (`GrocerySales::HttpError` with status, `RateLimitedError` for 429, `TimeoutError`). Faraday and HTTParty were considered and rejected: they add dependencies (and bundler-audit surface) for about two endpoints. WebMock works with `Net::HTTP` directly.

### Token caching in memory, per client instance
`KrogerClient` keeps the token and its expiry (`expires_in - 60 s` safety margin) in instance variables and fetches a new token when it expires. A run is a single process, so `Rails.cache` (Solid Cache) is not needed. The token request counts against the call budget, as the spec requires.

### Call budget enforced in the client
`KrogerClient` counts each request (token, locations, products) and raises `BudgetExceededError` *before* sending once `calls_made >= budget`. `SaleItemFinder` catches it and moves the current term and all remaining terms to `skipped_terms` with reason `budget`. On 429 it does the same with reason `rate_limited`. Other `HttpError` or `TimeoutError` failures go to `failed_terms` and the loop continues. Enforcing the budget in the client means no caller can bypass it.

Defaults: `call_budget: 200`, `max_pages_per_term: 1`, `page_size: 50` (the API's maximum). The worst case is 1 token + terms × pages, which is about 16 calls for the starting watchlist.

### Sale detection and deduplication
For each product, use the first `items[]` entry (the store-specific price). The product is on sale if `promo.to_f > 0 && promo < regular`. Prices are handled as `BigDecimal` from strings so savings math is exact. Products are deduplicated by `productId` into a hash, and each duplicate adds to `matched_terms`. Order is preserved (first-seen), so the brief lists items roughly in watchlist order.

### UPC to Open Food Facts barcode candidates
Kroger `upc` is 13 characters, zero-padded, and **leaves out the check digit** (for example `0001111041700`). `UpcCandidates` tries these forms in order and stops at the first match:
1. If the last 12 digits (the EAN-13 body) start with `0`, take the 11-digit UPC-A body and add the GS1 check digit → 12-digit UPC-A (for example `0001111041700` → `011110417008`).
2. The 12-digit body plus its check digit → EAN-13.
3. The raw Kroger value (in case it already includes a check digit).

Only distinct candidates are tried. This is at most 3 OFF calls per item, usually 1.

### Open Food Facts request and field mapping
`GET https://world.openfoodfacts.org/api/v2/product/<barcode>.json?fields=code,product_name,serving_size,nutriments`, with header `User-Agent: MealPrepper/0.1 (personal meal-planning tool)`. A contact can be configured through `sales_brief.yml` (`off_user_agent`); there is no default email. A match is `status == 1`. Mapping:
- calories ← `nutriments["energy-kcal_serving"]`
- protein_g ← `nutriments["proteins_serving"]`
- sodium_mg ← `nutriments["sodium_serving"] * 1000` (OFF stores sodium in grams)
- serving_size ← `serving_size`

`_100g` fields are deliberately ignored. Scaling them would be an estimate, which the spec forbids. Each missing field stays `nil`.

### Config: `config/sales_brief.yml` through `config_for`
```yaml
shared:
  location_id: ""            # set after running sales:locations
  call_budget: 200
  max_pages_per_term: 1
  page_size: 50
  output_dir: storage/sales_briefs
  watchlist:
    - chicken breast
    - ground turkey
    - salmon
    - lean ground beef
    - eggs
    - broccoli
    - frozen stir fry vegetables
    - brown rice
    - Banza pasta
    # …
  constraints:
    servings: 4
    days: Mon–Thu
    calories: [500, 700]
    protein_g: [40, 45]
    sodium_mg_max: 600
    notes:
      - Microwave-reheatable
      - Whole / minimally processed ingredients
      - Frozen vegetables for volume
  idea_count: 3
```
The location ID is not a secret, so it lives in config rather than credentials. Tests use `GrocerySales::Config.new(hash)` to inject values instead of reading the file.

### Rake tasks in `lib/tasks/sales.rake`
- `sales:locations[zip]`: requires a zip argument (for example `bin/rails "sales:locations[97005]"`) and prints a table of Fred Meyer stores. It does **not** send `filter.chain`. It fetches nearby stores and keeps those whose `chain`/`name` matches Fred Meyer in code. If a chain filter used the wrong value, the API would quietly return no stores, so the in-code check is the only filter.
- `sales:brief`: calls `BriefRun.new.call`, prints the paths, the item count, and any failed or skipped terms. It exits non-zero on configuration or auth errors.

Tasks stay thin. All logic is in services so tests target the services directly.

### Output files
`BriefRun` writes `<output_dir>/<Date.current.iso8601>.json` (`JSON.pretty_generate`) and `.md`. The directory is created if needed. Nil nutrition serializes to JSON `null`. The renderer prints `n/a` for nil and formats prices as `$%.2f`. The Markdown layout: a heading with the date and store ID, a Markdown table of sale items, a "Coverage notes" section (only if there are gaps), a "My lunch constraints" list, then the closing request.

### Testing approach
- Add `gem "webmock"` to the `:test` group. In `test_helper.rb`, `require "webmock/minitest"` and `WebMock.disable_net_connect!` so any unstubbed call fails the test.
- JSON response fixtures go in `test/fixtures/files/kroger/` and `test/fixtures/files/open_food_facts/`.
- Unit tests per service live under `test/services/grocery_sales/`. One end-to-end `BriefRun` test writes to a `Dir.mktmpdir` output dir with `travel_to` a fixed date. This is safe under parallel workers because each test uses its own tmpdir.
- Credentials are stubbed by injecting `client_id`/`client_secret` into `KrogerClient.new(...)`. Its defaults read `Rails.application.credentials.dig(:kroger, :client_id)`.

## Risks / Trade-offs

- [Kroger search relevance is fuzzy. "chicken breast" may return chicken broth or deli meat] → Accept for now. The brief is read by Claude and me, and irrelevant items are easy to ignore. Per-term exclude keywords can be added later without a spec change.
- [Only the first page (50) per term is checked, so sale items deeper in results are missed] → `max_pages_per_term` is configurable. Raising it is cheap compared with the budget.
- [Open Food Facts coverage of store brands (Kroger, Simple Truth) is patchy] → The spec requires blanks. The brief shows `n/a`, and Claude is told the values are missing rather than given made-up ones.
- [UPC check-digit assumption may be wrong for some items] → The candidate list also tries the raw value. A miss only means blank nutrition, never wrong data.
- [The Kroger chain code for Fred Meyer is not confirmed] → No chain filter is sent. Stores are matched by chain *or* name in code, so an unexpected chain code still matches on the "Fred Meyer" name.
- [Credentials could leak in error messages or logs] → Errors include status and endpoint path only, never request headers or bodies. `filter_parameter_logging.rb` is unaffected because this code does not go through controllers.
- [Promo prices may reflect loyalty-card pricing, not shelf price] → This is the intended signal for a Fred Meyer shopper. No mitigation needed.

## Migration Plan

No database or deploy impact. Rollout: `bundle install`, `bin/rails credentials:edit` to add the `kroger:` keys, `bin/rails "sales:locations[97005]"`, put the chosen ID in `config/sales_brief.yml`, then `bin/rails sales:brief`. To roll back, delete the files that were added.
