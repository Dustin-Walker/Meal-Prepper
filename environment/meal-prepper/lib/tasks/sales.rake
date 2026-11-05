namespace :sales do
  desc 'List Fred Meyer stores near a ZIP code (example: bin/rails "sales:locations[97005]")'
  task :locations, [ :zip ] => :environment do |_task, args|
    zip = args[:zip].to_s.strip
    abort 'Usage: bin/rails "sales:locations[ZIP]"  (e.g. 97005)' if zip.empty?

    config = GrocerySales::Config.new
    client = GrocerySales::KrogerClient.new(budget: config.call_budget)
    stores = GrocerySales::StoreLocator.new(client:).call(zip:)

    if stores.empty?
      puts "No Fred Meyer stores found near #{zip}."
    else
      puts "Fred Meyer stores near #{zip}:"
      stores.each { |store| puts "  #{store.location_id}  #{store.name}  —  #{store.address}" }
      puts
      puts "Copy a location ID into location_id in config/sales_brief.yml."
    end
  rescue GrocerySales::Error => e
    abort "sales:locations failed: #{e.message}"
  end

  desc "Fetch this week's Fred Meyer sale items for the watchlist and write a lunch-planning brief"
  task brief: :environment do
    result = GrocerySales::BriefRun.new.call

    puts "Found #{result.item_count} sale #{'item'.pluralize(result.item_count)} " \
         "(#{result.calls_made} Kroger API #{'call'.pluralize(result.calls_made)})."
    result.skipped_terms.group_by { it[:reason] }.each do |reason, entries|
      puts "Skipped (#{reason}): #{entries.map { it[:term] }.join(', ')}"
    end
    result.failed_terms.each { puts "Search failed for \"#{it[:term]}\": #{it[:error]}" }
    result.nutrition_failures.each { puts "Nutrition lookup failed for #{it[:description]}: #{it[:error]}" }
    puts "JSON snapshot: #{result.json_path}"
    puts "Brief:         #{result.markdown_path}"
  rescue GrocerySales::ConfigurationError, GrocerySales::AuthenticationError => e
    abort "sales:brief failed: #{e.message}"
  end
end
