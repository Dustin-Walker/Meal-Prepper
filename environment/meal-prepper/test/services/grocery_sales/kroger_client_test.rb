require "test_helper"
require "support/grocery_sales_stubs"

module GrocerySales
  class KrogerClientTest < ActiveSupport::TestCase
    include GrocerySalesStubs

    test "fetches one token and reuses it as a Bearer header" do
      token = stub_kroger_token
      chicken = stub_kroger_products("chicken breast", fixture: "products_chicken_breast.json")
      broccoli = stub_kroger_products("broccoli", fixture: "products_broccoli.json")
      client = kroger_client

      client.products(term: "chicken breast", location_id: LOCATION_ID, limit: 50)
      client.products(term: "broccoli", location_id: LOCATION_ID, limit: 50)

      assert_requested token, times: 1
      assert_requested chicken.with(headers: { "Authorization" => "Bearer test-access-token" })
      assert_requested broccoli.with(headers: { "Authorization" => "Bearer test-access-token" })
      assert_equal 3, client.calls_made
    end

    test "token request uses client credentials and the product.compact scope" do
      token = stub_kroger_token
      stub_kroger_products("eggs", fixture: "products_empty.json")

      kroger_client.products(term: "eggs", location_id: LOCATION_ID, limit: 50)

      assert_requested(token.with(basic_auth: %w[test-id test-secret]) do |req|
        URI.decode_www_form(req.body).to_h == { "grant_type" => "client_credentials", "scope" => "product.compact" }
      end)
    end

    test "requests a new token after the old one expires" do
      token = stub_kroger_token
      stub_kroger_products("eggs", fixture: "products_empty.json")
      client = kroger_client

      client.products(term: "eggs", location_id: LOCATION_ID, limit: 50)
      travel 30.minutes do
        client.products(term: "eggs", location_id: LOCATION_ID, limit: 50)
      end

      assert_requested token, times: 2
    end

    test "missing credentials stop before any HTTP call" do
      client = KrogerClient.new(budget: 10, client_id: "", client_secret: "")

      error = assert_raises(ConfigurationError) do
        client.products(term: "eggs", location_id: LOCATION_ID, limit: 50)
      end

      assert_includes error.message, "kroger.client_id"
      assert_includes error.message, "kroger.client_secret"
      assert_includes error.message, "bin/rails credentials:edit"
      assert_not_requested :any, /.*/
    end

    test "rejected token request reports status without the secret" do
      stub_kroger_token(status: 401)

      error = assert_raises(AuthenticationError) do
        kroger_client(client_secret: "super-secret-value").products(term: "eggs", location_id: LOCATION_ID, limit: 50)
      end

      assert_equal 401, error.status
      assert_includes error.message, "401"
      assert_not_includes error.message, "super-secret-value"
    end

    test "budget counts the token call and blocks requests once reached" do
      stub_kroger_token
      eggs = stub_kroger_products("eggs", fixture: "products_empty.json")
      client = kroger_client(budget: 2)

      client.products(term: "eggs", location_id: LOCATION_ID, limit: 50)
      assert_raises(BudgetExceededError) do
        client.products(term: "eggs", location_id: LOCATION_ID, limit: 50)
      end

      assert_requested eggs, times: 1
      assert_equal 2, client.calls_made
      assert_equal 0, client.remaining_budget
    end

    test "maps 429 to RateLimitedError" do
      stub_kroger_token
      stub_kroger_products("eggs", status: 429)

      assert_raises(RateLimitedError) { kroger_client.products(term: "eggs", location_id: LOCATION_ID, limit: 50) }
    end

    test "maps 500 to HttpError with status and path" do
      stub_kroger_token
      stub_kroger_products("eggs", status: 500)

      error = assert_raises(HttpError) { kroger_client.products(term: "eggs", location_id: LOCATION_ID, limit: 50) }
      assert_equal 500, error.status
      assert_equal "/v1/products", error.path
    end

    test "maps timeouts to TimeoutError" do
      stub_kroger_token
      stub_kroger_products("eggs", timeout: true)

      assert_raises(TimeoutError) { kroger_client.products(term: "eggs", location_id: LOCATION_ID, limit: 50) }
    end

    test "products query filters by term and store location" do
      stub_kroger_token
      stub = stub_request(:get, "#{KROGER}/v1/products")
        .with(query: { "filter.term" => "salmon", "filter.locationId" => LOCATION_ID, "filter.limit" => "50" })
        .to_return(body: file_fixture("kroger/products_empty.json").read)

      assert_equal [], kroger_client.products(term: "salmon", location_id: LOCATION_ID, limit: 50)
      assert_requested stub
    end

    test "products sends filter.start only for later pages" do
      stub_kroger_token
      stub = stub_request(:get, "#{KROGER}/v1/products")
        .with(query: hash_including("filter.start" => "50"))
        .to_return(body: file_fixture("kroger/products_empty.json").read)

      kroger_client.products(term: "salmon", location_id: LOCATION_ID, limit: 50, start: 50)
      assert_requested stub
    end

    test "locations query searches near the ZIP code" do
      stub_kroger_token
      stub = stub_request(:get, "#{KROGER}/v1/locations")
        .with(query: { "filter.zipCode.near" => "97005", "filter.limit" => "50" })
        .to_return(body: file_fixture("kroger/locations_97005.json").read)

      locations = kroger_client.locations(zip: "97005")

      assert_requested stub
      assert_equal 3, locations.size
      assert_equal "70100140", locations.first["locationId"]
    end
  end
end
