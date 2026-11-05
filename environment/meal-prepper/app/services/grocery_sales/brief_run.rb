module GrocerySales
  # One sales-brief run: find sale items → add nutrition → write the dated JSON
  # snapshot and Markdown brief to the output directory.
  class BriefRun
    Result = Data.define(:json_path, :markdown_path, :item_count, :failed_terms,
                         :skipped_terms, :nutrition_failures, :calls_made)

    def initialize(config: Config.new, kroger_client: nil, nutrition_lookup: nil)
      @config = config
      @kroger_client = kroger_client
      @nutrition_lookup = nutrition_lookup
    end

    def call
      location_id = @config.location_id!
      now = Time.current.in_time_zone(@config.time_zone)

      client = @kroger_client || KrogerClient.new(budget: @config.call_budget)
      found = SaleItemFinder.new(config: @config, client:).call
      lookup = @nutrition_lookup || NutritionLookup.new(user_agent: @config.off_user_agent)
      enriched = lookup.enrich(found.items)

      dir = @config.output_dir
      FileUtils.mkdir_p(dir)
      json_path = dir.join("#{now.to_date.iso8601}.json")
      markdown_path = dir.join("#{now.to_date.iso8601}.md")

      File.write(json_path, JSON.pretty_generate(snapshot(now, location_id, found, enriched)) + "\n")
      File.write(markdown_path, render(now, location_id, found, enriched))

      Result.new(json_path:, markdown_path:, item_count: enriched.items.size,
                 failed_terms: found.failed_terms, skipped_terms: found.skipped_terms,
                 nutrition_failures: enriched.failures, calls_made: found.calls_made)
    end

    private
      def snapshot(now, location_id, found, enriched)
        {
          generated_at: now.iso8601,
          location_id:,
          kroger_api_calls: found.calls_made,
          kroger_call_budget: @config.call_budget,
          watchlist: @config.watchlist,
          failed_terms: found.failed_terms,
          skipped_terms: found.skipped_terms,
          nutrition_failures: enriched.failures,
          items: enriched.items.map(&:to_h)
        }
      end

      def render(now, location_id, found, enriched)
        BriefRenderer.new(
          date: now.to_date, location_id:, items: enriched.items,
          constraints: @config.constraints, idea_count: @config.idea_count,
          failed_terms: found.failed_terms, skipped_terms: found.skipped_terms,
          nutrition_failures: enriched.failures
        ).render
      end
  end
end
