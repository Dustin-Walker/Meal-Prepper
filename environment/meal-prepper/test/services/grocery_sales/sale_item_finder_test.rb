require "test_helper"
require "support/grocery_sales_stubs"

module GrocerySales
  class SaleItemFinderTest < ActiveSupport::TestCase
    include GrocerySalesStubs

    setup { stub_kroger_token }

    def find(watchlist:, budget: 50, **config)
      config = Config.new({ location_id: LOCATION_ID, watchlist: }.merge(config))
      client = kroger_client(budget:)
      SaleItemFinder.new(config:, client:).call
    end

    test "keeps only items with promo > 0 and promo < regular" do
      stub_kroger_products("chicken breast", fixture: "products_chicken_breast.json")

      result = find(watchlist: [ "chicken breast" ])

      # Fixture has: promo below regular, promo 0, promo == regular, no price.
      assert_equal [ "0001111041700" ], result.items.map(&:product_id)
      item = result.items.first
      assert_equal BigDecimal("6.99"), item.regular_price
      assert_equal BigDecimal("4.99"), item.promo_price
      assert_equal "1 lb", item.size
      assert_equal "Kroger", item.brand
      assert_equal "0001111041700", item.upc
      assert_equal [ "chicken breast" ], item.matched_terms
    end

    test "drops items with a missing promo" do
      stub_kroger_products("broccoli", fixture: "products_broccoli.json")

      result = find(watchlist: [ "broccoli" ])

      assert_equal [ "Kroger Frozen Broccoli Florets" ], result.items.map(&:description)
    end

    test "searches each term once at the configured store" do
      chicken = stub_kroger_products("chicken breast", fixture: "products_chicken_breast.json")
      broccoli = stub_kroger_products("broccoli", fixture: "products_broccoli.json")

      result = find(watchlist: [ "chicken breast", "broccoli" ])

      assert_requested chicken, times: 1
      assert_requested broccoli, times: 1
      assert_equal 3, result.calls_made
      assert_empty result.failed_terms
      assert_empty result.skipped_terms
    end

    test "a product returned by two terms appears once with both terms" do
      stub_kroger_products("broccoli", fixture: "products_broccoli.json")
      stub_kroger_products("frozen broccoli", fixture: "products_frozen_broccoli.json")

      result = find(watchlist: [ "broccoli", "frozen broccoli" ])

      assert_equal 1, result.items.size
      assert_equal [ "broccoli", "frozen broccoli" ], result.items.first.matched_terms
    end

    test "fetches further pages up to max_pages_per_term while pages are full" do
      first = stub_request(:get, "#{KROGER}/v1/products")
        .with(query: { "filter.term" => "rice", "filter.locationId" => LOCATION_ID, "filter.limit" => "1" })
        .to_return(body: file_fixture("kroger/products_frozen_broccoli.json").read)
      second = stub_request(:get, "#{KROGER}/v1/products")
        .with(query: { "filter.term" => "rice", "filter.locationId" => LOCATION_ID, "filter.limit" => "1", "filter.start" => "1" })
        .to_return(body: file_fixture("kroger/products_empty.json").read)

      find(watchlist: [ "rice" ], page_size: 1, max_pages_per_term: 3)

      assert_requested first, times: 1
      assert_requested second, times: 1
    end

    test "a failing term is recorded and the others still searched" do
      stub_kroger_products("salmon", status: 500)
      stub_kroger_products("broccoli", fixture: "products_broccoli.json")

      result = find(watchlist: [ "salmon", "broccoli" ])

      assert_equal 1, result.items.size
      assert_equal [ "salmon" ], result.failed_terms.map { it[:term] }
      assert_includes result.failed_terms.first[:error], "500"
    end

    test "a timeout is recorded as a failed term" do
      stub_kroger_products("salmon", timeout: true)
      stub_kroger_products("broccoli", fixture: "products_broccoli.json")

      result = find(watchlist: [ "salmon", "broccoli" ])

      assert_equal [ "salmon" ], result.failed_terms.map { it[:term] }
      assert_equal 1, result.items.size
    end

    test "429 stops Kroger calls and skips the remaining terms" do
      stub_kroger_products("broccoli", fixture: "products_broccoli.json")
      eggs = stub_kroger_products("eggs", status: 429)
      salmon = stub_kroger_products("salmon", fixture: "products_empty.json")

      result = find(watchlist: [ "broccoli", "eggs", "salmon" ])

      assert_equal 1, result.items.size
      assert_requested eggs, times: 1
      assert_not_requested salmon
      assert_equal [ { term: "eggs", reason: "rate_limited" }, { term: "salmon", reason: "rate_limited" } ], result.skipped_terms
    end

    test "budget of 5 with 10 terms makes at most 5 calls and lists skipped terms" do
      terms = (1..10).map { "term #{it}" }
      terms.each { stub_kroger_products(it, fixture: "products_empty.json") }

      result = find(watchlist: terms, budget: 5)

      assert_equal 5, result.calls_made
      assert_requested :any, %r{api\.kroger\.com}, times: 5
      assert_equal terms[4..], result.skipped_terms.map { it[:term] }
      assert result.skipped_terms.all? { it[:reason] == "budget" }
    end

    test "blank location_id stops before any Products call" do
      config = Config.new({ location_id: "", watchlist: [ "eggs" ] })

      error = assert_raises(ConfigurationError) { SaleItemFinder.new(config:, client: kroger_client).call }

      assert_includes error.message, "location_id"
      assert_includes error.message, "sales:locations"
      assert_not_requested :any, %r{api\.kroger\.com}
    end
  end
end
