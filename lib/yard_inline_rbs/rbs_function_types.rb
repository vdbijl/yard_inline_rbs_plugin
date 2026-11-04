# frozen_string_literal: true

module YardInlineRbs
  # The parameter and return types of an RBS function type, e.g. `(Integer x) -> bool`, as YARD
  # type strings.
  class RbsFunctionTypes
    # @rbs @function: RBS::Types::Function

    # @rbs (RBS::Types::Function function) -> void
    def initialize(function)
      @function = function
    end

    # @rbs () -> Array[PositionalParamType]
    def positional_types
      positionals.map do |param|
        PositionalParamType.new(type: RbsTypeFormatter.format(param.type),
                                name: param.name&.to_s)
      end
    end

    # An unnamed keyword rest is recorded under `ParameterNames::KEYWORD_REST_KEY`.
    # @rbs () -> Hash[String, NamedParamAnnotation]
    def named_types
      rest = @function.rest_keywords
      keywords.transform_values do |param|
        NamedParamAnnotation.new(type: RbsTypeFormatter.format(param.type),
                                 rest: param.equal?(rest))
      end
    end

    # @rbs () -> Array[String]
    def yield_types
      positionals.map {|param| RbsTypeFormatter.format(param.type)}
    end

    # @rbs () -> String
    def return_type
      RbsTypeFormatter.format(@function.return_type)
    end

    private

    # Ruby order: required, optional, rest, trailing.
    # @rbs () -> Array[RBS::Types::Function::Param]
    def positionals
      @function.required_positionals + @function.optional_positionals +
        [@function.rest_positionals].compact + @function.trailing_positionals
    end

    # @rbs () -> Hash[String, RBS::Types::Function::Param]
    def keywords
      result = @function.required_keywords.merge(@function.optional_keywords)
                        .transform_keys(&:to_s)
      rest = @function.rest_keywords
      result[rest.name&.to_s || ParameterNames::KEYWORD_REST_KEY] = rest if rest
      result
    end
  end
end
