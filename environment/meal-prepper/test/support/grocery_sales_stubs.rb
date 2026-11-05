# WebMock helpers for the GrocerySales tests. Fixtures live in
# test/fixtures/files/kroger and test/fixtures/files/open_food_facts.
module GrocerySalesStubs
  KROGER = "https://api.kroger.com"
  OFF = "https://world.openfoodfacts.org"
  LOCATION_ID = "70100140"

  def stub_kroger_token(status: 200)
    stub_request(:post, "#{KROGER}/v1/connect/oauth2/token")
      .to_return(status:, body: status == 200 ? file_fixture("kroger/token.json").read : '{"error":"invalid_client"}',
                 headers: { "Content-Type" => "application/json" })
  end

  # Stubs a Products search for `term`; `fixture` is a file under kroger/, or pass status:/timeout:.
  def stub_kroger_products(term, fixture: nil, status: 200, timeout: false, location_id: LOCATION_ID)
    stub = stub_request(:get, "#{KROGER}/v1/products")
      .with(query: hash_including("filter.term" => term, "filter.locationId" => location_id))
    return stub.to_timeout if timeout

    body = fixture ? file_fixture("kroger/#{fixture}").read : "{}"
    stub.to_return(status:, body:, headers: { "Content-Type" => "application/json" })
  end

  # Stubs an Open Food Facts product lookup. `fixture` under open_food_facts/; nil → not-found response.
  def stub_off_product(barcode, fixture: nil, timeout: false)
    stub = stub_request(:get, %r{\A#{Regexp.escape(OFF)}/api/v2/product/#{barcode}\.json})
    return stub.to_timeout if timeout

    if fixture
      stub.to_return(status: 200, body: file_fixture("open_food_facts/#{fixture}").read,
                     headers: { "Content-Type" => "application/json" })
    else
      stub.to_return(status: 404, body: { code: barcode, status: 0, status_verbose: "product not found" }.to_json,
                     headers: { "Content-Type" => "application/json" })
    end
  end

  # Any OFF lookup not stubbed explicitly returns "not found". Call this before
  # stub_off_product: WebMock uses the most recently declared matching stub.
  def stub_off_not_found_by_default
    stub_request(:get, %r{\A#{Regexp.escape(OFF)}/api/v2/product/})
      .to_return(status: 404, body: { status: 0, status_verbose: "product not found" }.to_json)
  end

  # Makes KrogerClient.new (as called by the rake tasks) use test credentials.
  def use_test_kroger_credentials
    original = GrocerySales::KrogerClient.credentials_provider
    GrocerySales::KrogerClient.credentials_provider = -> { { client_id: "test-id", client_secret: "test-secret" } }
    original
  end

  def kroger_client(budget: 50, client_id: "test-id", client_secret: "test-secret")
    GrocerySales::KrogerClient.new(budget:, client_id:, client_secret:)
  end
end
