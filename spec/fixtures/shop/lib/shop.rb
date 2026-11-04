# frozen_string_literal: true

# A shop.
class Shop
  # The name of the shop.
  attr_reader :name #: String

  # Adds an item.
  # @rbs item: String -- the item to add
  # @rbs return: bool
  def add(item); end

  # Removes items. Typed in sig/shop.rbs only.
  def remove(item, count = 1); end

  # Typed inline and in sig/shop.rbs: the inline annotation wins, with a warning.
  #: (Integer) -> String
  def label(width); end

  def clear; end

  # Has an annotation that is not valid RBS.
  # @rbs item: Array[
  def broken(item); end
end
