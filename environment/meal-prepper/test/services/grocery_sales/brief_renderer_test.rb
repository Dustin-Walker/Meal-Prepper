require "test_helper"

module GrocerySales
  class BriefRendererTest < ActiveSupport::TestCase
    DEFAULT_CONSTRAINTS = {
      servings: 4, days: "Mon–Thu", calories: [ 500, 700 ], protein_g: [ 40, 45 ], sodium_mg_max: 600,
      notes: [ "Microwave-reheatable", "Whole / minimally processed ingredients", "Frozen vegetables for volume" ]
    }.freeze

    def chicken(nutrition: Nutrition.new(calories: 120, protein_g: 26, sodium_mg: 70, serving_size: "112 g", barcode: "011110417008"))
      SaleItem.new(product_id: "0001111041700", upc: "0001111041700", description: "Kroger Boneless Skinless Chicken Breast",
                   brand: "Kroger", size: "1 lb", regular_price: BigDecimal("6.99"), promo_price: BigDecimal("4.99"),
                   matched_terms: [ "chicken breast" ], nutrition:)
    end

    def render(items: [ chicken ], constraints: DEFAULT_CONSTRAINTS, **options)
      BriefRenderer.new(date: Date.new(2026, 11, 4), location_id: "70100140", items:,
                        constraints:, idea_count: 3, **options).render
    end

    test "item row shows prices, savings, size and nutrition" do
      brief = render

      assert_includes brief,
        "| Kroger Boneless Skinless Chicken Breast | Kroger | 1 lb | $6.99 | $4.99 | $2.00 | 112 g | 120 | 26 g | 70 mg |"
      assert_includes brief, "70100140"
    end

    test "missing nutrition shows n/a, never 0" do
      brief = render(items: [ chicken(nutrition: Nutrition.blank) ])

      assert_includes brief, "| $6.99 | $4.99 | $2.00 | n/a | n/a | n/a | n/a |"
      assert_no_match(/\| 0 g \|/, brief)
    end

    test "states the default lunch constraints" do
      brief = render

      assert_includes brief, "- 4 servings — the same lunch Mon–Thu"
      assert_includes brief, "- 500–700 calories per serving"
      assert_includes brief, "- 40–45 g protein per serving"
      assert_includes brief, "- Under ~600 mg sodium per serving"
      assert_includes brief, "- Microwave-reheatable"
      assert_includes brief, "- Whole / minimally processed ingredients"
      assert_includes brief, "- Frozen vegetables for volume"
    end

    test "uses the constraint values from config" do
      brief = render(constraints: DEFAULT_CONSTRAINTS.merge(protein_g: [ 35, 40 ]))

      assert_includes brief, "- 35–40 g protein per serving"
      assert_not_includes brief, "40–45 g"
    end

    test "ends by asking for 3 ideas and no full recipes" do
      last_section = render.split("\n## ").last

      assert last_section.start_with?("What I'd like")
      assert_includes last_section, "suggest 3 meal-prep lunch ideas"
      assert_includes last_section, "don't write full recipes yet"
    end

    test "names skipped and failed terms in coverage notes" do
      brief = render(skipped_terms: [ { term: "salmon", reason: "budget" }, { term: "eggs", reason: "budget" } ],
                     failed_terms: [ { term: "rice", error: "HTTP 500 from /v1/products" } ])

      assert_includes brief, "## Coverage notes"
      assert_includes brief, "- Not searched (call budget reached): salmon, eggs"
      assert_includes brief, "- Search failed for \"rice\": HTTP 500 from /v1/products"
    end

    test "no coverage notes when nothing was missed" do
      assert_not_includes render, "Coverage notes"
    end

    test "says when nothing is on sale" do
      brief = render(items: [])

      assert_includes brief, "No watchlist items are on sale this week."
      assert_includes brief, "## My lunch constraints"
    end

    test "escapes pipes in table cells" do
      item = chicken.with(description: "Chicken | Family Pack")

      assert_includes render(items: [ item ]), "| Chicken \\| Family Pack |"
    end
  end
end
