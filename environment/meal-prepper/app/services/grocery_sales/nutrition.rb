module GrocerySales
  # Per-serving nutrition taken as-is from Open Food Facts. Any value may be nil;
  # nil means "not provided by the source", never zero and never estimated.
  Nutrition = Data.define(:calories, :protein_g, :sodium_mg, :serving_size, :barcode) do
    def self.blank = new(calories: nil, protein_g: nil, sodium_mg: nil, serving_size: nil, barcode: nil)

    # True when Open Food Facts had a product for this item (even if some values are missing).
    def matched? = !barcode.nil?

    def to_h
      { matched: matched?, calories:, protein_g:, sodium_mg:, serving_size:, off_barcode: barcode }
    end
  end
end
