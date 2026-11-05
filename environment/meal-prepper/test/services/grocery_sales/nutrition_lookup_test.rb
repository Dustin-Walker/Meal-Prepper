require "test_helper"
require "support/grocery_sales_stubs"

module GrocerySales
  class NutritionLookupTest < ActiveSupport::TestCase
    include GrocerySalesStubs

    CHICKEN_UPC = "0001111041700"   # → 011110417008, 0011110417008, raw
    BROCCOLI_UPC = "0001111079150"  # → 011110791504, 0011110791504, raw

    def lookup = NutritionLookup.new(user_agent: "MealPrepper/0.1 (test)")

    def sale_item(upc:, product_id: upc, description: "Item #{upc}")
      SaleItem.new(product_id:, upc:, description:, brand: "Kroger", size: "1 lb",
                   regular_price: BigDecimal("5"), promo_price: BigDecimal("4"), matched_terms: [ "x" ])
    end

    test "full match records per-serving values and converts sodium to mg" do
      stub_off_product("011110417008", fixture: "chicken_breast_full.json")

      nutrition = lookup.call(CHICKEN_UPC)

      assert nutrition.matched?
      assert_equal 120, nutrition.calories
      assert_equal 26, nutrition.protein_g
      assert_equal 70, nutrition.sodium_mg
      assert_equal "112 g", nutrition.serving_size
      assert_equal "011110417008", nutrition.barcode
    end

    test "matches on the second barcode candidate" do
      first = stub_off_product("011110417008")
      stub_off_product("0011110417008", fixture: "chicken_breast_full.json")

      nutrition = lookup.call(CHICKEN_UPC)

      assert_requested first
      assert_equal "0011110417008", nutrition.barcode
      assert_equal 26, nutrition.protein_g
    end

    test "a 200 response with status 0 is treated as no match" do
      stub_request(:get, %r{/api/v2/product/011110417008\.json})
        .to_return(status: 200, body: file_fixture("open_food_facts/not_found_status_0.json").read)
      stub_off_product("0011110417008")
      stub_off_product("0001111041700")

      assert_not lookup.call(CHICKEN_UPC).matched?
    end

    test "partial data keeps what is present and leaves the rest nil" do
      stub_off_product("011110791504", fixture: "broccoli_partial.json")

      nutrition = lookup.call(BROCCOLI_UPC)

      assert nutrition.matched?
      assert_equal 25, nutrition.calories
      assert_equal 2.5, nutrition.protein_g
      assert_nil nutrition.sodium_mg, "sodium_100g must not be scaled into a per-serving value"
    end

    test "per-100g-only data leaves every value nil" do
      stub_off_product("011110417008", fixture: "per_100g_only.json")

      nutrition = lookup.call(CHICKEN_UPC)

      assert nutrition.matched?
      assert_nil nutrition.calories
      assert_nil nutrition.protein_g
      assert_nil nutrition.sodium_mg
    end

    test "no match on any candidate gives blank nutrition" do
      stub_off_not_found_by_default

      nutrition = lookup.call(CHICKEN_UPC)

      assert_not nutrition.matched?
      assert_equal Nutrition.blank, nutrition
      assert_requested :get, %r{openfoodfacts\.org}, times: 3
    end

    test "item without a UPC makes no request" do
      assert_equal Nutrition.blank, lookup.call(nil)
      assert_not_requested :any, %r{openfoodfacts\.org}
    end

    test "sends the configured User-Agent and asks only for needed fields" do
      stub = stub_request(:get, "#{OFF}/api/v2/product/011110417008.json")
        .with(query: { "fields" => NutritionLookup::FIELDS }, headers: { "User-Agent" => "MealPrepper/0.1 (test)" })
        .to_return(body: file_fixture("open_food_facts/chicken_breast_full.json").read)

      lookup.call(CHICKEN_UPC)

      assert_requested stub
    end

    test "a timeout leaves that item blank, is recorded, and the next item is enriched" do
      stub_off_product("011110417008", timeout: true)
      stub_off_product("011110791504", fixture: "broccoli_partial.json")
      items = [ sale_item(upc: CHICKEN_UPC, description: "Chicken"), sale_item(upc: BROCCOLI_UPC, description: "Broccoli") ]

      result = lookup.enrich(items)

      chicken, broccoli = result.items
      assert_equal Nutrition.blank, chicken.nutrition
      assert_equal 25, broccoli.nutrition.calories
      assert_equal 1, result.failures.size
      assert_equal "Chicken", result.failures.first[:description]
      assert_match(/Timed out/, result.failures.first[:error])
    end

    test "a server error is recorded as a failure" do
      stub_request(:get, %r{/api/v2/product/011110417008\.json}).to_return(status: 503)

      result = lookup.enrich([ sale_item(upc: CHICKEN_UPC) ])

      assert_equal Nutrition.blank, result.items.first.nutrition
      assert_includes result.failures.first[:error], "503"
    end
  end
end
