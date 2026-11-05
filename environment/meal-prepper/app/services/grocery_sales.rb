# Namespace for the Fred Meyer sales brief. Shared error classes live here so
# Zeitwerk loads them with the namespace itself.
module GrocerySales
  class Error < StandardError; end

  # Missing or invalid setup (credentials, location_id). The run cannot start.
  class ConfigurationError < Error; end

  # Non-success HTTP response. Carries the status and the endpoint path only,
  # never headers or bodies, so credentials cannot leak into messages.
  class HttpError < Error
    attr_reader :status, :path

    def initialize(status:, path:, message: nil)
      @status = status
      @path = path
      super(message || "HTTP #{status} from #{path}")
    end
  end

  # HTTP 429 from the Kroger API.
  class RateLimitedError < HttpError; end

  # Kroger rejected the client-credentials token request. Not an HttpError on
  # purpose: per-term search failures are skipped, but auth failure ends the run.
  class AuthenticationError < Error
    attr_reader :status

    def initialize(status:)
      @status = status
      super("Kroger token request failed with HTTP #{status}. Check kroger.client_id / kroger.client_secret.")
    end
  end

  # Open or read timeout talking to an external API.
  class TimeoutError < Error; end

  # Could not connect at all (DNS, refused, TLS).
  class ConnectionError < Error; end

  # The per-run Kroger call budget is used up; raised before a request is sent.
  class BudgetExceededError < Error; end
end
