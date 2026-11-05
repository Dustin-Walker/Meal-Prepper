module GrocerySales
  # Searches each watchlist term at the configured store and keeps products on sale
  # (promo > 0 and promo < regular). Products found by several terms are kept once.
  #
  # A failing term is recorded and skipped. A 429 or an exhausted call budget stops
  # all further searching; the remaining terms are reported as skipped.
  class SaleItemFinder
    Result = Data.define(:items, :failed_terms, :skipped_terms, :calls_made)

    def initialize(config:, client:)
      @config = config
      @client = client
    end

    def call
      location_id = @config.location_id!
      terms = @config.watchlist
      found = {}
      failed = []
      skipped = []

      terms.each_with_index do |term, index|
        search(term, location_id, found)
      rescue BudgetExceededError
        skipped.concat(terms[index..].map { { term: it, reason: "budget" } })
        break
      rescue RateLimitedError
        skipped.concat(terms[index..].map { { term: it, reason: "rate_limited" } })
        break
      rescue HttpError, TimeoutError, ConnectionError => e
        failed << { term:, error: e.message }
      end

      Result.new(items: found.values, failed_terms: failed, skipped_terms: skipped, calls_made: @client.calls_made)
    end

    private
      def search(term, location_id, found)
        limit = @config.page_size

        @config.max_pages_per_term.times do |page|
          products = begin
            @client.products(term:, location_id:, limit:, start: page * limit)
          rescue BudgetExceededError
            raise if page.zero?

            break # this term was partly searched; the next term reports the budget stop
          end

          products.each { |product| record(product, term, found) }
          break if products.size < limit
        end
      end

      def record(product, term, found)
        id = product["productId"]
        if found.key?(id)
          found[id] = found[id].add_term(term) unless found[id].matched_terms.include?(term)
          return
        end

        item = sale_item(product, term)
        found[id] = item if item
      end

      def sale_item(product, term)
        store_item = Array(product["items"]).first.to_h
        regular = price(store_item.dig("price", "regular"))
        promo = price(store_item.dig("price", "promo"))
        return unless regular && promo && promo.positive? && promo < regular

        SaleItem.new(
          product_id: product["productId"],
          upc: product["upc"].presence,
          description: product["description"],
          brand: product["brand"],
          size: store_item["size"],
          regular_price: regular,
          promo_price: promo,
          matched_terms: [ term ]
        )
      end

      def price(value)
        return if value.nil?

        BigDecimal(value.to_s)
      rescue ArgumentError
        nil
      end
  end
end
