module GrocerySales
  # Looks up per-serving calories, protein and sodium on Open Food Facts by UPC.
  #
  # Only *_serving values are used. Per-100g values are ignored on purpose:
  # scaling them to a serving would be an estimate. Missing values stay nil.
  class NutritionLookup
    BASE_URL = "https://world.openfoodfacts.org"
    FIELDS = "code,product_name,serving_size,nutriments"

    Result = Data.define(:items, :failures)

    def initialize(user_agent:)
      @user_agent = user_agent
    end

    # Enriches every item. A failed lookup leaves that item's nutrition blank,
    # is recorded in `failures`, and does not stop the others.
    def enrich(items)
      failures = []
      enriched = items.map do |item|
        item.with(nutrition: call(item.upc))
      rescue HttpError, TimeoutError, ConnectionError => e
        failures << { product_id: item.product_id, description: item.description, error: e.message }
        item.with(nutrition: Nutrition.blank)
      end
      Result.new(items: enriched, failures:)
    end

    # Nutrition for the first barcode candidate Open Food Facts knows, or Nutrition.blank.
    def call(upc)
      UpcCandidates.for(upc).each do |barcode|
        product = fetch(barcode)
        return nutrition_from(product, barcode) if product
      end
      Nutrition.blank
    end

    private
      def fetch(barcode)
        uri = URI("#{BASE_URL}/api/v2/product/#{barcode}.json")
        uri.query = URI.encode_www_form(fields: FIELDS)
        request = Net::HTTP::Get.new(uri)
        request["User-Agent"] = @user_agent

        response = JsonHttp.perform(uri, request)
        return nil if response.status == 404
        raise HttpError.new(status: response.status, path: uri.path) unless response.success?

        json = response.json.to_h
        json["status"].to_i == 1 ? json.fetch("product", {}) : nil
      end

      def nutrition_from(product, barcode)
        nutriments = product.fetch("nutriments", {}).to_h
        sodium_g = number(nutriments["sodium_serving"])

        Nutrition.new(
          calories: tidy(number(nutriments["energy-kcal_serving"])),
          protein_g: tidy(number(nutriments["proteins_serving"])),
          sodium_mg: sodium_g && tidy(sodium_g * 1000),
          serving_size: product["serving_size"].presence,
          barcode:
        )
      end

      def number(value)
        return if value.nil? || value == ""

        Float(value)
      rescue ArgumentError, TypeError
        nil
      end

      # Display normalisation only (float noise, 120.0 → 120); never fills a gap.
      def tidy(value)
        return if value.nil?

        rounded = value.round(1)
        rounded == rounded.to_i ? rounded.to_i : rounded
      end
  end
end
