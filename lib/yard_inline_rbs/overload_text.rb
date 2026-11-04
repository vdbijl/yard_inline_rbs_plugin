# frozen_string_literal: true

module YardInlineRbs
  # The text of an @overload tag for one signature of a method, in the format YARD parses:
  # the call on the first line, then the nested tags.
  class OverloadText
    # @rbs @name: Symbol
    # @rbs @signature: signature

    # The name of a keyword rest that has none.
    KEYWORD_REST_NAME = 'options' #: String

    # @rbs (Symbol name, signature signature) -> void
    def initialize(name, signature)
      @name = name
      @signature = signature
    end

    # @rbs () -> String
    def to_s
      lines = ["#{@name}(#{call_arguments.join(', ')})"]
      lines += params.map {|name, type| "  @param #{name} [#{type}]"}
      lines += block_lines
      lines << "  @return [#{@signature[:return_type]}]"
      lines.join("\n")
    end

    private

    # @rbs () -> Array[String]
    def call_arguments
      positional_names + keywords.map do |name, annotation|
        annotation.rest ? "**#{name}" : "#{name}:"
      end
    end

    # @rbs () -> Array[String]
    def positional_names
      @signature[:positional_types].each_with_index.map do |param, index|
        param.name || ParameterNames.placeholder(index)
      end
    end

    # @rbs () -> Array[[String, String?]]
    def params
      positional = @signature[:positional_types].map(&:type)
      positional_names.zip(positional) + keywords.transform_values(&:type).to_a
    end

    # @rbs () -> Hash[String, NamedParamAnnotation]
    def keywords
      @signature[:named_types].transform_keys do |name|
        name == ParameterNames::KEYWORD_REST_KEY ? KEYWORD_REST_NAME : name
      end
    end

    # @rbs () -> Array[String]
    def block_lines
      block = @signature[:block_annotation]
      return [] if block.nil?

      ["  @yield [#{block.yield_types.join(', ')}]", "  @yieldreturn [#{block.return_type}]"]
    end
  end
end
