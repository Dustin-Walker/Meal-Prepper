require "test_helper"

module GrocerySales
  class UpcCandidatesTest < ActiveSupport::TestCase
    test "Kroger UPC becomes UPC-A, then EAN-13, then the raw value" do
      assert_equal %w[011110417008 0011110417008 0001111041700], UpcCandidates.for("0001111041700")
    end

    test "matches a known real UPC-A check digit" do
      # Nutella 13 oz: UPC-A 009800895007; Kroger stores it as 0000980089500.
      assert_equal "009800895007", UpcCandidates.for("0000980089500").first
    end

    test "non-US EAN body yields only the EAN-13 and the raw value" do
      # Nutella (EU) EAN-13 3017620422003.
      assert_equal %w[3017620422003 0301762042200], UpcCandidates.for("0301762042200")
    end

    test "blank or all-zero UPC yields no candidates" do
      assert_equal [], UpcCandidates.for(nil)
      assert_equal [], UpcCandidates.for("")
      assert_equal [], UpcCandidates.for("0000000000000")
    end

    test "candidates are distinct" do
      candidates = UpcCandidates.for("011110417008")
      assert_equal candidates.uniq, candidates
    end
  end
end
