module GrocerySales
  # Typed access to config/sales_brief.yml. Tests pass a hash instead of reading the file.
  class Config
    DEFAULTS = {
      location_id: nil,
      call_budget: 200,
      max_pages_per_term: 1,
      page_size: 50,
      output_dir: "storage/sales_briefs",
      time_zone: "Pacific Time (US & Canada)",
      off_user_agent: "MealPrepper/0.1 (personal meal-planning tool)",
      watchlist: [],
      constraints: {},
      idea_count: 3
    }.freeze

    MAX_PAGE_SIZE = 50

    # Where Config.new reads its values when none are passed; tests swap this
    # out to drive the rake tasks.
    mattr_accessor :source, default: -> { Rails.application.config_for(:sales_brief) }

    def initialize(values = nil)
      values = self.class.source.call if values.nil?
      @values = DEFAULTS.merge(values.to_h.deep_symbolize_keys.compact)
    end

    def location_id
      @values[:location_id].to_s.strip.presence
    end

    # The store ID, or a ConfigurationError telling the user how to find one.
    def location_id!
      location_id || raise(ConfigurationError,
        "No store set: location_id is blank in config/sales_brief.yml. " \
        "Run `bin/rails \"sales:locations[ZIP]\"` to find your Fred Meyer location ID.")
    end

    def call_budget = Integer(@values[:call_budget])
    def max_pages_per_term = [ Integer(@values[:max_pages_per_term]), 1 ].max
    def page_size = Integer(@values[:page_size]).clamp(1, MAX_PAGE_SIZE)
    def idea_count = Integer(@values[:idea_count])
    def off_user_agent = @values[:off_user_agent].to_s.presence || DEFAULTS[:off_user_agent]
    def constraints = @values[:constraints].to_h

    def time_zone
      ActiveSupport::TimeZone[@values[:time_zone].to_s] ||
        raise(ConfigurationError, "Unknown time_zone #{@values[:time_zone].inspect} in config/sales_brief.yml")
    end

    def output_dir
      Rails.root.join(@values[:output_dir].to_s)
    end

    def watchlist
      Array(@values[:watchlist]).map { it.to_s.strip }.reject(&:empty?).uniq
    end
  end
end
