module Validations

  class Validation
    def self.validates_format_of string, regex
      raise ArgumentError, "Validation error. '#{string}' does not match '#{regex.inspect}'" unless regex.match(string)
    end
  end
end