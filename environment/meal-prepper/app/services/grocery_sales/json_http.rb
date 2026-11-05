require "net/http"

module GrocerySales
  # Minimal Net::HTTP wrapper shared by the Kroger and Open Food Facts clients:
  # sets timeouts, maps network failures to typed errors, parses JSON bodies.
  # Status handling is left to the caller (a 404 means different things per API).
  module JsonHttp
    Response = Data.define(:status, :json) do
      def success? = status.between?(200, 299)
    end

    OPEN_TIMEOUT = 5
    READ_TIMEOUT = 10

    module_function

    def perform(uri, request, open_timeout: OPEN_TIMEOUT, read_timeout: READ_TIMEOUT)
      request["Accept"] = "application/json"
      http_response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == "https",
                                      open_timeout:, read_timeout:) do |http|
        http.request(request)
      end
      Response.new(status: http_response.code.to_i, json: parse(http_response.body))
    rescue Net::OpenTimeout, Net::ReadTimeout
      raise TimeoutError, "Timed out calling #{uri.host}#{uri.path}"
    rescue SocketError, SystemCallError, OpenSSL::SSL::SSLError, IOError => e
      raise ConnectionError, "Could not reach #{uri.host}#{uri.path} (#{e.class})"
    end

    def parse(body)
      return nil if body.blank?

      JSON.parse(body)
    rescue JSON::ParserError
      nil
    end
  end
end
