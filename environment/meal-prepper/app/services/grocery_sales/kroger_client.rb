module GrocerySales
  # Kroger Public API client (Fred Meyer is a Kroger banner).
  #
  # - OAuth2 client-credentials token (scope product.compact), reused until it expires.
  # - Every request, the token request included, counts against a per-run budget;
  #   once the budget is used up, BudgetExceededError is raised before sending.
  class KrogerClient
    BASE_URL = "https://api.kroger.com"
    TOKEN_PATH = "/v1/connect/oauth2/token"
    LOCATIONS_PATH = "/v1/locations"
    PRODUCTS_PATH = "/v1/products"
    SCOPE = "product.compact"
    EXPIRY_MARGIN = 60.seconds

    # Where default credentials come from; tests swap this out for the rake tasks.
    mattr_accessor :credentials_provider, default: -> { Rails.application.credentials.kroger.to_h }

    attr_reader :calls_made, :budget

    def initialize(budget:, client_id: nil, client_secret: nil)
      @budget = budget
      defaults = client_id && client_secret ? {} : credentials_provider.call.to_h.symbolize_keys
      @client_id = client_id || defaults[:client_id]
      @client_secret = client_secret || defaults[:client_secret]
      @calls_made = 0
      @token = nil
      @token_expires_at = nil
    end

    def locations(zip:, limit: 50)
      get(LOCATIONS_PATH, "filter.zipCode.near" => zip, "filter.limit" => limit)
        .fetch("data", [])
    end

    # One page of products for a search term, priced at the given store.
    # `start` is the number of products to skip (0 for the first page).
    def products(term:, location_id:, limit:, start: 0)
      query = { "filter.term" => term, "filter.locationId" => location_id, "filter.limit" => limit }
      query["filter.start"] = start if start.positive?
      get(PRODUCTS_PATH, query).fetch("data", [])
    end

    def remaining_budget = [ budget - calls_made, 0 ].max

    private
      def get(path, query)
        uri = URI.join(BASE_URL, path)
        uri.query = URI.encode_www_form(query)
        request = Net::HTTP::Get.new(uri)
        request["Authorization"] = "Bearer #{access_token}"

        response = send_counted(uri, request)
        raise RateLimitedError.new(status: 429, path:) if response.status == 429
        raise HttpError.new(status: response.status, path:) unless response.success?
        raise HttpError.new(status: response.status, path:, message: "Unreadable JSON from #{path}") unless response.json.is_a?(Hash)

        response.json
      end

      def access_token
        return @token if @token && Time.current < @token_expires_at

        ensure_credentials!
        uri = URI.join(BASE_URL, TOKEN_PATH)
        request = Net::HTTP::Post.new(uri)
        request.basic_auth(@client_id, @client_secret)
        request.set_form_data("grant_type" => "client_credentials", "scope" => SCOPE)

        response = send_counted(uri, request)
        raise RateLimitedError.new(status: 429, path: TOKEN_PATH) if response.status == 429
        raise AuthenticationError.new(status: response.status) unless response.success? && response.json&.dig("access_token")

        @token_expires_at = Time.current + response.json.fetch("expires_in", 1800).to_i.seconds - EXPIRY_MARGIN
        @token = response.json["access_token"]
      end

      def send_counted(uri, request)
        raise BudgetExceededError, "Kroger call budget of #{budget} reached" if calls_made >= budget

        @calls_made += 1
        JsonHttp.perform(uri, request)
      end

      def ensure_credentials!
        missing = []
        missing << "kroger.client_id" if @client_id.blank?
        missing << "kroger.client_secret" if @client_secret.blank?
        return if missing.empty?

        raise ConfigurationError,
          "Missing Kroger API credentials: #{missing.join(', ')}. " \
          "Add them with `bin/rails credentials:edit`."
      end
  end
end
