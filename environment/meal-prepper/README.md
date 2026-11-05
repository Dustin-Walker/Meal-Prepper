# Meal Prepper

This directory is for the Ruby on Rails component of the Meal Prepper application.

## Important Dependencies
* Ruby version
  * 4.0.5
* Rails version
  * 8.1.3

## Setup
1. Install the system dependencies
```terminaloutput
brew install rbenv
brew install bundle
rbenv install 4.0.5
rbenv global 4.0.5
gem install rails
bundle install
```
2. Update the database
```terminaloutput
bin/rails db:migrate
```
3. Run the rails app
```terminaloutput
bin/rails server
```


## Fred Meyer sales brief
A manually run task that checks a watchlist of lunch staples for sale prices at your
Fred Meyer store (via the Kroger Public API), adds per-serving nutrition from
Open Food Facts, and writes a Markdown brief to paste into Claude chat.

1. Create an app at [developer.kroger.com](https://developer.kroger.com) with the
   `product.compact` scope, then add its credentials:
```terminaloutput
bin/rails credentials:edit
```
```yaml
kroger:
  client_id: your-client-id
  client_secret: your-client-secret
```
2. Find your store's location ID:
```terminaloutput
bin/rails "sales:locations[97005]"
```
3. Put the ID in `location_id` in `config/sales_brief.yml`. The watchlist, call budget,
   and lunch constraints are in the same file.
4. Generate the brief:
```terminaloutput
bin/rails sales:brief
```
Output goes to `storage/sales_briefs/YYYY-MM-DD.json` (snapshot) and
`storage/sales_briefs/YYYY-MM-DD.md` (the brief to paste). Nutrition that Open Food Facts
doesn't have is shown as `n/a` and is never estimated.

## Deployment
- TODO Fill this in once it is ready