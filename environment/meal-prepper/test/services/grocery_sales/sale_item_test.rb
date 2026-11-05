require "test_helper"

module GrocerySales
  class SaleItemTest < ActiveSupport::TestCase
    def item(**overrides)
      SaleItem.new(product_id: "0001111041700", upc: "0001111041700", description: "Chicken Breast",
                   brand: "Kroger", size: "1 lb", regular_price: BigDecimal("6.99"), promo_price: BigDecimal("4.99"),
                   matched_terms: [ "chicken breast" ], **overrides)
    end

    test "savings is exact" do
      assert_equal BigDecimal("2.00"), item.savings
      assert_equal BigDecimal("0.01"), item(regular_price: BigDecimal("0.30"), promo_price: BigDecimal("0.29")).savings
    end

    test "add_term keeps terms unique" do
      assert_equal [ "chicken breast", "chicken" ], item.add_term("chicken").add_term("chicken").matched_terms
    end

    test "to_h has JSON-friendly prices and nil nutrition" do
      hash = item.to_h

      assert_equal 6.99, hash[:regular_price]
      assert_equal 4.99, hash[:promo_price]
      assert_equal 2.0, hash[:savings]
      assert_equal [ "chicken breast" ], hash[:matched_terms]
      assert_equal({ matched: false, calories: nil, protein_g: nil, sodium_mg: nil, serving_size: nil, off_barcode: nil },
                   hash[:nutrition])
    end
  end
end
