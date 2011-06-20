require 'terminal-table/import'

class String
  def indent(n)
     if n >= 0
       gsub(/^/, ' ' * n)
     else
       gsub(/^ {0,#{-n}}/, "")
     end
   end
end


class View
  def initialize(name, items, keys)
    @name = name
    @items = items
    @keys = keys
  end

  def index
    rows = @items.collect { |item| collect_values(item) }
    "#{@name}:\n#{rows.empty? ? "None\n".indent(2) : table(@keys, *rows).to_s.indent(2)}"
  end

  def show(i)
    "#{@name}:\n" +
    table(nil, *@keys.collect { |item| item }.zip( collect_values(@items[i]))).to_s.indent(2)
  end

  private
  def collect_values(item)
    @keys.collect { |key|
      v = item.is_a?(Hash) ? (item.has_key?(key) && item.fetch(key) || item.has_key?(key.to_sym) && item.fetch(key.to_sym)) : item.send(key)
      v.inspect
    }
  end
end

