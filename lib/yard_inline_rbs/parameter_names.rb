# frozen_string_literal: true

module YardInlineRbs
  # The parameter names of a method object, as YARD records them: 'x', '*rest', 'name:'.
  class ParameterNames
    # @rbs @object: YARD::CodeObjects::Base
    # @rbs @raw: Array[String]?

    # The key of a keyword rest without a name, in the keywords of `RbsFunctionTypes`.
    KEYWORD_REST_KEY = '**' #: String

    # The name of an unnamed parameter, e.g. of a method that only exists in a `.rbs` file.
    # @rbs (Integer index) -> String
    def self.placeholder(index)
      "arg#{index}"
    end

    # @rbs (YARD::CodeObjects::Base object) -> void
    def initialize(object)
      @object = object
    end

    # @rbs () -> bool
    def empty?
      raw.empty?
    end

    # The positional names in Ruby order, without the '*' prefix.
    # @rbs () -> Array[String]
    def positional
      raw.reject {|name| name.end_with?(':') || name.start_with?('**', '&')}
         .map {|name| name.delete_prefix('*')}
    end

    # All names as @param tags spell them; YARD renders them in this order.
    # @rbs () -> Array[String]
    def tag_order
      raw.map {|name| name.sub(/\A[*&]+/, '').delete_suffix(':')}
    end

    # Resolves the placeholder of an unnamed splat ('*') or keyword rest ('**') annotation.
    #
    # Returns `name` itself if it is no placeholder.
    # @rbs (String name) -> String
    def resolve_splat(name)
      return name unless %w[* **].include?(name)

      raw_name = raw.find do |param_name|
        param_name.start_with?(name) && !param_name.start_with?("#{name}*")
      end
      actual_name = raw_name.to_s.delete_prefix(name)
      actual_name.empty? ? name : actual_name
    end

    private

    # @rbs () -> Array[String]
    def raw
      object = @object
      return [] unless object.is_a?(YARD::CodeObjects::MethodObject)

      @raw ||= object.parameters.map(&:first)
    end
  end
end
