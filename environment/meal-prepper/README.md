# Meal Prepper

The Ruby on Rails part of the Meal Prepper app. Run every command below from this directory
(`environment/meal-prepper/`).

## Stack
- Ruby 3.4.3 (see `.ruby-version`)
- Rails 8.1.3 with SQLite
- Hotwire (Turbo + Stimulus) with import maps, so there's no Node or webpack
- Solid Queue (jobs), Solid Cache (caching), Solid Cable (WebSockets)
- Minitest, with WebMock blocking all live HTTP in the test suite

## Setup
1. Install Ruby with rbenv. `rbenv install` with no version reads `.ruby-version`:
```bash
brew install rbenv
rbenv install
```
2. Install gems, prepare the database, and start the server:
```bash
bin/setup
```
   To set up without starting the server, run `bin/setup --skip-server`.

## Running the app
```bash
bin/dev
```
The app runs at http://localhost:3000. Docker is only used for production, so don't use it for local development.

## Tests and checks
Run the whole test suite:
```bash
bin/rails test
```
Run one test file:
```bash
bin/rails test test/services/grocery_sales/sale_item_finder_test.rb
```
Run the linter (RuboCop, using the Rails omakase style):
```bash
bin/rubocop
```
Run the full CI suite: setup, lint, gem and importmap audits, Brakeman, tests, and a seed check:
```bash
bin/ci
```
Tests never call real external APIs. `test/test_helper.rb` turns on `WebMock.disable_net_connect!`, so every HTTP call must be stubbed (see `test/support/grocery_sales_stubs.rb`).

## Fred Meyer sales brief
A task you run by hand. It checks a watchlist of lunch staples for sale prices at your Fred Meyer store through the
[Kroger Public API](https://developer.kroger.com) (Fred Meyer is a Kroger banner) and adds per-serving nutrition from
[Open Food Facts](https://world.openfoodfacts.org). It then writes a Markdown brief to paste into Claude chat when you plan the week's lunches.

### One-time setup
1. Create an app at [developer.kroger.com](https://developer.kroger.com) with the `product.compact` scope.
   Then add its credentials:
```bash
bin/rails credentials:edit
```
```yaml
kroger:
  client_id: your-client-id
  client_secret: your-client-secret
```
2. Find your store's location ID:
```bash
bin/rails "sales:locations[97005]"
```
3. Copy the ID into `location_id` in `config/sales_brief.yml`.

### Weekly run
```bash
bin/rails sales:brief
```
This writes two files, named with today's date:
- `storage/sales_briefs/YYYY-MM-DD.md`: the brief to paste into Claude. It has a sale-item table (regular price, sale price, savings,
  size, and per-serving calories, protein, and sodium), any coverage gaps, your lunch constraints, and a request for lunch ideas.
- `storage/sales_briefs/YYYY-MM-DD.json`: a snapshot of the same data, including how many API calls the run made.

Running it again on the same day overwrites that day's files. `storage/` is gitignored.

### How it decides what's on sale
- Kroger has no "all sales" endpoint, so only the watchlist terms are searched, one search per term at your store.
- An item counts as on sale when its promo price is above $0 and below the regular price.
- A product that matches several terms is listed once.
- Nutrition comes from Open Food Facts per-serving values only. When a value is missing, the brief shows `n/a`. It is
  never estimated or worked out from per-100g data.
- If a search fails, the run carries on, and the brief lists the missing terms under "Coverage notes".

### Configuration (`config/sales_brief.yml`)
| Key | What it does |
|---|---|
| `location_id` | Your Fred Meyer store's Kroger location ID (find it with `sales:locations`) |
| `watchlist` | Search terms to check for sales; add or remove items freely |
| `constraints` | Servings, calorie, protein, and sodium targets, and notes stated in the brief |
| `idea_count` | How many lunch ideas the brief asks for |
| `call_budget` | Most Kroger API calls per run, including the token request (Kroger allows 10,000/day) |
| `max_pages_per_term` / `page_size` | How deep to search each term (50 results per page at most) |
| `output_dir` | Where the files are written |
| `time_zone` | Time zone used to date the files (the app itself runs in UTC) |
| `off_user_agent` | User-Agent sent to Open Food Facts |

## Deployment
Not set up yet. The `Dockerfile` is for production only, built for Kamal and Thruster.
