require "test_helper"
require "support/grocery_sales_stubs"
require "support/rake_task_helper"

class SalesBriefTaskTest < ActiveSupport::TestCase
  include GrocerySalesStubs
  include RakeTaskHelper

  setup do
    @dir = Dir.mktmpdir("sales_briefs")
    @original_provider = use_test_kroger_credentials
    @original_source = GrocerySales::Config.source
    use_config(location_id: LOCATION_ID)
  end

  teardown do
    GrocerySales::KrogerClient.credentials_provider = @original_provider
    GrocerySales::Config.source = @original_source
    FileUtils.remove_entry(@dir)
  end

  def use_config(**values)
    base = { output_dir: @dir, watchlist: [ "chicken breast", "salmon" ], constraints: { servings: 4 } }
    GrocerySales::Config.source = -> { base.merge(values) }
  end

  test "prints file paths, item count and failed terms" do
    stub_kroger_token
    stub_kroger_products("chicken breast", fixture: "products_chicken_breast.json")
    stub_kroger_products("salmon", status: 500)
    stub_off_not_found_by_default

    out, = travel_to(Time.zone.parse("2026-11-04 12:00 -08:00")) { capture_io { run_rake_task("sales:brief") } }

    assert_includes out, "Found 1 sale item (3 Kroger API calls)."
    assert_includes out, "Search failed for \"salmon\""
    assert_includes out, File.join(@dir, "2026-11-04.json")
    assert_includes out, File.join(@dir, "2026-11-04.md")
    assert File.exist?(File.join(@dir, "2026-11-04.md"))
  end

  test "missing location_id exits non-zero before calling Kroger" do
    use_config(location_id: "")

    error = nil
    _, err = capture_io { error = assert_raises(SystemExit) { run_rake_task("sales:brief") } }

    assert_not error.success?
    assert_includes err, "location_id"
    assert_not_requested :any, /.*/
  end

  test "rejected Kroger credentials exit non-zero" do
    stub_kroger_token(status: 401)

    error = nil
    _, err = capture_io { error = assert_raises(SystemExit) { run_rake_task("sales:brief") } }

    assert_not error.success?
    assert_includes err, "401"
  end
end
