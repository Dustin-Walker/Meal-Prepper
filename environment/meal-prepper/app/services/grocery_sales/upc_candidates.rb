module GrocerySales
  # Turns a Kroger UPC into the barcodes Open Food Facts might know it by.
  #
  # Kroger UPCs are 13 characters: the 12-digit EAN-13 body, zero-padded, with
  # no check digit (e.g. "0001111041700"). Candidates, in order:
  #   1. 12-digit UPC-A with check digit (when the body is a US UPC, i.e. starts with 0)
  #   2. 13-digit EAN-13 with check digit
  #   3. the raw value, in case it already carries a check digit
  module UpcCandidates
    module_function

    def for(upc)
      digits = upc.to_s.gsub(/\D/, "")
      return [] if digits.empty? || digits.delete("0").empty?

      body12 = digits.rjust(12, "0").last(12)
      candidates = []
      candidates << with_check_digit(body12[1..]) if body12.start_with?("0")
      candidates << with_check_digit(body12)
      candidates << digits
      candidates.uniq
    end

    # GS1 check digit: from the right, weights 3,1,3,1,...
    def check_digit(body)
      sum = body.reverse.each_char.with_index.sum { |char, index| char.to_i * (index.even? ? 3 : 1) }
      (10 - (sum % 10)) % 10
    end

    def with_check_digit(body) = "#{body}#{check_digit(body)}"
  end
end
