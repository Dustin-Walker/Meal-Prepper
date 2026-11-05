module GrocerySales
  # A watchlist product on sale at the configured store. Prices are BigDecimal.
  SaleItem = Data.define(:product_id, :upc, :description, :brand, :size,
                         :regular_price, :promo_price, :matched_terms, :nutrition) do
    def initialize(matched_terms: [], nutrition: Nutrition.blank, **rest)
      super(matched_terms: matched_terms.uniq.freeze, nutrition:, **rest)
    end

    def savings = regular_price - promo_price

    def add_term(term) = with(matched_terms: matched_terms + [ term ])

    def to_h
      {
        product_id:, upc:, description:, brand:, size:,
        regular_price: regular_price.to_f, promo_price: promo_price.to_f, savings: savings.to_f,
        matched_terms:,
        nutrition: nutrition.to_h
      }
    end
  end
end
