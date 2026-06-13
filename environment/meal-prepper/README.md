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

## Deployment
- TODO Fill this in once it is ready