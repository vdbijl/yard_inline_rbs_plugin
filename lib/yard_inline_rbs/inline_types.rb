# frozen_string_literal: true

module YardInlineRbs
  # What the inline annotations of an object typed, such as `the return type`, and where they
  # are. RbsFileTags warns when a `.rbs` file types the same. It is stored on the object and
  # replaced with each docstring, so it follows the docstring that YARD keeps, also in its cache.
  class InlineTypes
    # Stores nothing on an object that had no inline types and still has none.
    # @rbs (YARD::CodeObjects::Base object, Array[String] typed, String location) -> void
    def self.record(object, typed, location)
      return if typed.empty? && !any?(object)

      object[:rbs_inline_typed] = typed
      object[:rbs_inline_location] = location
    end

    # @rbs (YARD::CodeObjects::Base object, String annotated) -> bool
    def self.typed?(object, annotated)
      typed(object).include?(annotated)
    end

    # @rbs (YARD::CodeObjects::Base object) -> bool
    def self.any?(object)
      typed(object).any?
    end

    # @rbs (YARD::CodeObjects::Base object) -> String?
    # @return [String, nil] The location of the inline annotations, such as `lib/shop.rb:7`.
    def self.location(object)
      object[:rbs_inline_location]
    end

    # @rbs (YARD::CodeObjects::Base object) -> Array[String]
    def self.typed(object)
      Array(object[:rbs_inline_typed])
    end
    private_class_method :typed
  end
end
