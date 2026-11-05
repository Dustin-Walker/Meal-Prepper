require "test_helper"
require "support/grocery_sales_stubs"

module GrocerySales
  class BriefRunTest < ActiveSupport::TestCase
    include GrocerySalesStubs

    setup do
      @dir = Dir.mktmpdir("sales_briefs")
      stub_kroger_token
      stub_kroger_products("chicken breast", fixture: "products_chicken_breast.json")
      stub_kroger_products("broccoli", fixture: "products_broccoli.json")
      stub_off_not_found_by_default # declared first: WebMock prefers the most recent matching stub
      stub_off_product("011110417008", fixture: "chicken_breast_full.json")
    end

    teardown { FileUtils.remove_entry(@dir) }

    def config(**overrides)
      Config.new({
        location_id: LOCATION_ID, output_dir: @dir, watchlist: [ "chicken breast", "broccoli" ],
        constraints: { servings: 4, protein_g: [ 40, 45 ] }
      }.merge(overrides))
    end

    def run_brief(config = self.config)
      BriefRun.new(config:, kroger_client: kroger_client(budget: config.call_budget)).call
    end

    test "writes dated JSON and Markdown files end to end" do
      result = travel_to(Time.zone.parse("2026-11-04 18:00 -08:00")) { run_brief }

      assert_equal Pathname(@dir).join("2026-11-04.json"), result.json_path
      assert_equal Pathname(@dir).join("2026-11-04.md"), result.markdown_path
      assert_equal 2, result.item_count
      assert_equal 3, result.calls_made

      json = JSON.parse(File.read(result.json_path))
      assert_equal LOCATION_ID, json["location_id"]
      assert_equal 3, json["kroger_api_calls"]
      assert_equal [], json["failed_terms"]
      assert_equal [], json["skipped_terms"]
      assert json["generated_at"].start_with?("2026-11-04T18:00:00")

      chicken, broccoli = json["items"]
      assert_equal 6.99, chicken["regular_price"]
      assert_equal 4.99, chicken["promo_price"]
      assert_equal "1 lb", chicken["size"]
      assert_equal "0001111041700", chicken["upc"]
      assert_equal [ "chicken breast" ], chicken["matched_terms"]
      assert_equal 26, chicken.dig("nutrition", "protein_g")
      assert_nil broccoli.dig("nutrition", "calories"), "missing nutrition must be null, not 0"
      assert_equal false, broccoli.dig("nutrition", "matched")

      markdown = File.read(result.markdown_path)
      assert_includes markdown, "Kroger Boneless Skinless Chicken Breast"
      assert_includes markdown, "Kroger Frozen Broccoli Florets"
    end

    test "dates files in the configured time zone, not UTC" do
      # 7pm Pacific on Nov 4 is already Nov 5 in UTC.
      result = travel_to(Time.utc(2026, 11, 5, 3, 0)) { run_brief }

      assert_equal "2026-11-04.md", result.markdown_path.basename.to_s
    end

    test "a second run on the same day overwrites that day's files" do
      travel_to(Time.zone.parse("2026-11-04 09:00 -08:00")) { run_brief }
      travel_to(Time.zone.parse("2026-11-04 17:00 -08:00")) { run_brief(config(watchlist: [ "broccoli" ])) }

      assert_equal %w[2026-11-04.json 2026-11-04.md], Dir.children(@dir).sort
      assert_equal 1, JSON.parse(File.read(File.join(@dir, "2026-11-04.json")))["items"].size
    end

    test "creates the output directory" do
      nested = File.join(@dir, "nested", "briefs")

      result = travel_to(Time.zone.parse("2026-11-04 12:00 -08:00")) { run_brief(config(output_dir: nested)) }

      assert File.exist?(result.json_path)
    end

    test "still writes files and a note when nothing is on sale" do
      stub_kroger_products("eggs", fixture: "products_empty.json")

      result = travel_to(Time.zone.parse("2026-11-04 12:00 -08:00")) { run_brief(config(watchlist: [ "eggs" ])) }

      assert_equal 0, result.item_count
      assert_equal [], JSON.parse(File.read(result.json_path))["items"]
      assert_includes File.read(result.markdown_path), "No watchlist items are on sale this week."
    end

    test "records skipped terms in the snapshot and the brief" do
      result = travel_to(Time.zone.parse("2026-11-04 12:00 -08:00")) { run_brief(config(call_budget: 2)) }

      json = JSON.parse(File.read(result.json_path))
      assert_equal [ { "term" => "broccoli", "reason" => "budget" } ], json["skipped_terms"]
      assert_includes File.read(result.markdown_path), "Not searched (call budget reached): broccoli"
    end
  end
end
