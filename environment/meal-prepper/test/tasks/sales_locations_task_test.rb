require "test_helper"
require "support/grocery_sales_stubs"
require "support/rake_task_helper"

class SalesLocationsTaskTest < ActiveSupport::TestCase
  include GrocerySalesStubs
  include RakeTaskHelper

  setup do
    @original_provider = use_test_kroger_credentials
    stub_kroger_token
  end

  teardown { GrocerySales::KrogerClient.credentials_provider = @original_provider }

  test "lists only Fred Meyer stores with ID, name and address" do
    stub_request(:get, "#{KROGER}/v1/locations").with(query: hash_including("filter.zipCode.near" => "97005"))
      .to_return(body: file_fixture("kroger/locations_97005.json").read)

    out, = capture_io { run_rake_task("sales:locations", "97005") }

    assert_includes out, "70100140  Fred Meyer - Beaverton  —  11425 SW Beaverton Hillsdale Hwy, Beaverton, OR 97005"
    assert_includes out, "70100023  Fred Meyer - Raleigh Hills"
    assert_not_includes out, "Kroger Fuel Center"
    assert_includes out, "config/sales_brief.yml"
  end

  test "reports when no stores are found" do
    stub_request(:get, "#{KROGER}/v1/locations").with(query: hash_including("filter.zipCode.near" => "99999"))
      .to_return(body: file_fixture("kroger/locations_empty.json").read)

    out, = capture_io { run_rake_task("sales:locations", "99999") }

    assert_includes out, "No Fred Meyer stores found near 99999."
  end

  test "requires a ZIP argument" do
    error = nil
    capture_io { error = assert_raises(SystemExit) { run_rake_task("sales:locations") } }

    assert_not error.success?
  end
end
