require "test_helper"

module GrocerySales
  class ConfigTest < ActiveSupport::TestCase
    test "applies defaults for missing keys" do
      config = Config.new({})

      assert_equal 200, config.call_budget
      assert_equal 1, config.max_pages_per_term
      assert_equal 50, config.page_size
      assert_equal 3, config.idea_count
      assert_equal Rails.root.join("storage/sales_briefs"), config.output_dir
      assert_equal [], config.watchlist
    end

    test "blank location_id is reported as missing" do
      config = Config.new({ location_id: "  " })

      assert_nil config.location_id
      error = assert_raises(ConfigurationError) { config.location_id! }
      assert_includes error.message, "location_id"
      assert_includes error.message, "sales:locations"
    end

    test "reads location_id and cleans the watchlist" do
      config = Config.new({ location_id: "70100123", watchlist: [ " eggs ", "eggs", "", "salmon" ] })

      assert_equal "70100123", config.location_id!
      assert_equal %w[eggs salmon], config.watchlist
    end

    test "page_size is capped at the API maximum" do
      assert_equal 50, Config.new({ page_size: 500 }).page_size
    end

    test "loads config/sales_brief.yml by default" do
      config = Config.new

      assert_includes config.watchlist, "chicken breast"
      assert_equal 4, config.constraints[:servings]
      assert_equal [ 40, 45 ], config.constraints[:protein_g]
    end
  end
end
