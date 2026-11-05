# Tasks

All paths are relative to `environment/meal-prepper/`.

## 1. Setup

- [x] 1.1 Add `gem "webmock"` to the `:test` group, run `bundle install`, and verify `bin/bundler-audit` passes
- [x] 1.2 In `test/test_helper.rb`, add `require "webmock/minitest"` and `WebMock.disable_net_connect!`, then verify the existing suite still passes with `bin/rails test`
- [x] 1.3 Create `config/sales_brief.yml` (`shared:` block with empty `location_id`, `call_budget: 200`, `max_pages_per_term: 1`, `page_size: 50`, `output_dir`, the starter watchlist, constraints, and `idea_count: 3`), and verify `bin/rails runner 'p Rails.application.config_for(:sales_brief)'` prints it
- [x] 1.4 Add `GrocerySales::Config` (wraps `config_for`, accepts an injected hash, exposes typed readers with defaults) and the shared error classes (`HttpError`, `RateLimitedError`, `TimeoutError`, `BudgetExceededError`, `ConfigurationError`), and verify with `test/services/grocery_sales/config_test.rb` (defaults applied; blank `location_id` reported as missing)

## 2. Kroger client and store lookup

- [x] 2.1 Implement `GrocerySales::KrogerClient` token handling (client-credentials, scope `product.compact`, credentials from `Rails.application.credentials.dig(:kroger, ...)` or injected; in-memory token reuse until expiry minus 60 s), and verify with WebMock tests: one token request for several calls, Bearer header sent, missing-credential error names keys and `bin/rails credentials:edit`, rejected token error includes status and does not include the secret
- [x] 2.2 Add the call counter and budget to `KrogerClient` (token calls count; raises `BudgetExceededError` before sending once the budget is reached) plus timeout and HTTP error mapping (429 → `RateLimitedError`), and verify with tests for budget cutoff, 429 mapping, 500 mapping, and timeout mapping
- [x] 2.3 Add `KrogerClient#locations(zip:)` and `#products(term:, location_id:, start:, limit:)` with JSON fixtures in `test/fixtures/files/kroger/`, and verify with tests that the request query includes `filter.zipCode.near`, `filter.term`, and `filter.locationId`
- [x] 2.4 Add the `sales:locations[zip]` rake task in `lib/tasks/sales.rake` (keeps only Fred Meyer stores by chain/name; prints location ID, name, and address; prints a "no stores found" message when empty), and verify with a test that runs the task against stubbed responses and checks the output (Fred Meyer only, and the empty case)

## 3. Sale item search

- [x] 3.1 Add the `GrocerySales::SaleItem` value object (product ID, UPC, description, brand, size, regular/promo as BigDecimal, matched terms, nutrition, `savings`, `to_h`), and verify with unit tests for `savings` and `to_h`
- [x] 3.2 Implement `GrocerySales::SaleItemFinder` sale detection (promo > 0 and promo < regular; drop items with no promo, promo equal to regular, or no store price), and verify with fixture-driven tests that cover each scenario in the `kroger-sale-items` "Sale item detection" requirement
- [x] 3.3 Add watchlist iteration with pagination (`max_pages_per_term`) and dedup by product ID that merges matched terms, and verify with tests that each term is searched once with the location filter, and that a product returned by two terms appears once with both terms
- [x] 3.4 Add failure handling to `SaleItemFinder`: HTTP error or timeout → `failed_terms` and continue; 429 → the current term and remaining terms go to `skipped_terms` (reason `rate_limited`); budget reached → `skipped_terms` (reason `budget`). Verify with tests for a 500 on one term, a 429 mid-run, and a budget of 5 with 10 terms (≤ 5 calls made, skipped terms listed)
- [x] 3.5 Make `SaleItemFinder` raise `ConfigurationError` before any Products call when `location_id` is blank, with a message naming `location_id` and `sales:locations`, and verify with a test that checks no Products request was made

## 4. Nutrition enrichment

- [x] 4.1 Implement `GrocerySales::UpcCandidates` (12-digit UPC-A with computed GS1 check digit, 13-digit EAN form, raw value; distinct; empty for a blank UPC), and verify with unit tests including `0001111041700` → `011110417008` and a known real UPC (Nutella `009800895007`)
- [x] 4.2 Implement `GrocerySales::NutritionLookup` (OFF v2 product endpoint with `fields=`, User-Agent from config defaulting to the app name, tries candidates until `status == 1`, maps `*_serving` fields, converts sodium g → mg, ignores `_100g`), with fixtures in `test/fixtures/files/open_food_facts/`. Verify with tests for a full match, a match on the second candidate, partial data, per-100g-only data (all nil), no match, and the User-Agent header
- [x] 4.3 Add failure handling: an OFF timeout or HTTP error leaves nutrition nil, records the failure, and moves on. Verify with a test where one item times out and the next is enriched

## 5. Brief output

- [x] 5.1 Implement `GrocerySales::BriefRenderer` (heading with date and store, sale-item table with $-formatted regular/promo/savings, size, and n/a for nil nutrition; coverage notes for failed or skipped terms; "no watchlist items on sale" message; constraints from config; closing request for `idea_count` ideas with no full recipes). Verify with tests covering each `lunch-brief` brief scenario, including a changed protein target
- [x] 5.2 Implement `GrocerySales::BriefRun` (finder → enrichment → write `<output_dir>/<date>.json` with timestamp, location ID, items with null nutrition, failed/skipped terms, and call count; write `<date>.md`; create the directory; overwrite on the same day; return paths and counts). Verify with an end-to-end WebMock test using `travel_to` and a `Dir.mktmpdir` output dir that checks both files and the JSON shape
- [x] 5.3 Add the `sales:brief` rake task (prints both paths, the item count, and failed/skipped terms; exits non-zero on `ConfigurationError` or auth failure), and verify with a task test against stubbed HTTP and a test that a missing `location_id` exits non-zero
- [x] 5.4 Add a short "Fred Meyer sales brief" section to the project README covering credentials setup (`kroger.client_id` / `kroger.client_secret`), `sales:locations[97005]`, setting `location_id`, editing the watchlist, and `sales:brief`. Verify that the documented commands match the task names

## 6. Integration checks

- [ ] 6.1 Run `bin/ci` (rubocop, bundler-audit, importmap audit, brakeman, tests, seed replant) and verify it passes with no live network calls
- [ ] 6.2 Manual smoke run (needs real credentials): run `bin/rails "sales:locations[97005]"`, set `location_id`, run `bin/rails sales:brief`, and verify the `.md` file in `storage/sales_briefs/` pastes cleanly into Claude chat and that the reported call count is well under budget. Confirm that `sales:locations` lists your Fred Meyer store
