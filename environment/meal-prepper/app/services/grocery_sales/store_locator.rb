module GrocerySales
  # Lists Fred Meyer stores near a ZIP code so the user can pick a location_id.
  #
  # Filters by chain/name in code instead of sending filter.chain: if Kroger's
  # chain code for Fred Meyer were different from what we expect, a query filter
  # would quietly return no stores.
  class StoreLocator
    Store = Data.define(:location_id, :name, :address)

    FRED_MEYER = /\A(fred|fred meyer)\z|fred meyer/i

    def initialize(client:)
      @client = client
    end

    def call(zip:)
      @client.locations(zip:).filter_map do |location|
        next unless fred_meyer?(location)

        Store.new(location_id: location["locationId"], name: location["name"], address: format_address(location["address"]))
      end
    end

    private
      def fred_meyer?(location)
        location["chain"].to_s.match?(FRED_MEYER) || location["name"].to_s.match?(FRED_MEYER)
      end

      def format_address(address)
        address = address.to_h
        street = address["addressLine1"]
        locality = [ address["city"], [ address["state"], address["zipCode"] ].compact.join(" ") ].compact_blank.join(", ")
        [ street, locality ].compact_blank.join(", ")
      end
  end
end
