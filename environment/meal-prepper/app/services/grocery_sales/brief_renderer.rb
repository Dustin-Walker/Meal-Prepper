module GrocerySales
  # Renders the Markdown brief that gets pasted into Claude chat: sale items,
  # coverage notes, lunch constraints, then the request for lunch ideas.
  class BriefRenderer
    NA = "n/a"
    SKIP_REASONS = { "budget" => "call budget reached", "rate_limited" => "Kroger rate limit" }.freeze

    def initialize(date:, location_id:, items:, constraints:, idea_count:,
                   failed_terms: [], skipped_terms: [], nutrition_failures: [])
      @date = date
      @location_id = location_id
      @items = items
      @constraints = constraints.to_h.symbolize_keys
      @idea_count = idea_count
      @failed_terms = failed_terms
      @skipped_terms = skipped_terms
      @nutrition_failures = nutrition_failures
    end

    def render
      [ header, sale_items_section, coverage_section, constraints_section, request_section ]
        .compact.join("\n\n") + "\n"
    end

    private
      def header
        <<~MD.chomp
          # Fred Meyer sale items — #{@date.strftime('%a %b %-d, %Y')}

          Store: Fred Meyer (Kroger location #{@location_id}). Prices are this store's regular and sale prices from the Kroger API. Nutrition is per serving from Open Food Facts; "#{NA}" means the data wasn't available, not zero.
        MD
      end

      def sale_items_section
        return "## Sale items\n\nNo watchlist items are on sale this week." if @items.empty?

        rows = @items.map do |item|
          n = item.nutrition
          cells = [
            item.description, item.brand, item.size,
            money(item.regular_price), money(item.promo_price), money(item.savings),
            n.serving_size, value(n.calories), value(n.protein_g, " g"), value(n.sodium_mg, " mg")
          ]
          "| #{cells.map { cell(it) }.join(' | ')} |"
        end

        <<~MD.chomp
          ## Sale items (#{@items.size})

          | Item | Brand | Size | Regular | Sale | You save | Serving | Calories | Protein | Sodium |
          |---|---|---|---:|---:|---:|---|---:|---:|---:|
          #{rows.join("\n")}
        MD
      end

      def coverage_section
        notes = []
        @skipped_terms.group_by { it[:reason] }.each do |reason, entries|
          notes << "- Not searched (#{SKIP_REASONS.fetch(reason, reason)}): #{entries.map { it[:term] }.join(', ')}"
        end
        @failed_terms.each { notes << "- Search failed for \"#{it[:term]}\": #{it[:error]}" }
        @nutrition_failures.each { notes << "- Nutrition lookup failed for #{it[:description]}: #{it[:error]}" }
        return if notes.empty?

        "## Coverage notes\n\nThis list may be incomplete:\n\n#{notes.join("\n")}"
      end

      def constraints_section
        c = @constraints
        lines = []
        lines << "#{c[:servings]} servings — the same lunch #{c[:days] || 'each day'}" if c[:servings]
        lines << "#{range(c[:calories])} calories per serving" if c[:calories]
        lines << "#{range(c[:protein_g])} g protein per serving" if c[:protein_g]
        lines << "Under ~#{c[:sodium_mg_max]} mg sodium per serving" if c[:sodium_mg_max]
        lines.concat(Array(c[:notes]).map(&:to_s))
        return if lines.empty?

        "## My lunch constraints\n\n#{lines.map { "- #{it}" }.join("\n")}"
      end

      def request_section
        <<~MD.chomp
          ## What I'd like

          Using the sale items above (plus basic pantry staples as needed), suggest #{@idea_count} meal-prep lunch ideas that fit my constraints. For each idea, give a one-line description, which sale items it uses, and rough per-serving calories, protein, and sodium. Please don't write full recipes yet — I'll pick one first.
        MD
      end

      def money(amount) = format("$%.2f", amount)

      def value(number, unit = "")
        number.nil? ? NA : "#{number}#{unit}"
      end

      def range(value)
        Array(value).join("–")
      end

      def cell(text)
        text.to_s.presence&.gsub("|", "\\|")&.gsub(/\s+/, " ") || NA
      end
  end
end
