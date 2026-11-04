# frozen_string_literal: true

module YardInlineRbs
  # Parses RBS type strings into YARD types, recording invalid ones as parse errors.
  class TypeParser
    # @rbs @parse_errors: Array[String]

    # @rbs (Array[String] parse_errors) -> void
    def initialize(parse_errors)
      @parse_errors = parse_errors
    end

    # RBS returns nil for empty text instead of raising.
    # @rbs (String text) -> String?
    def type(text)
      rbs_type = RBS::Parser.parse_type(text, require_eof: true)
      rbs_type ? RbsTypeFormatter.format(rbs_type) : record_error(text)
    rescue RBS::ParsingError
      record_error(text)
    end

    # A method type starts with its parameters, type parameters, block or arrow:
    # `(Integer) -> String`, `[T] (T) -> T`, `{ () -> void } -> void`, `-> Integer`. A proc type
    # (`^(Integer) -> String`) and a tuple, record or generic type that contains one also have an
    # arrow, but they are plain types. Invalid text such as `(Integer` is recorded as the same parse
    # error, whether it is parsed as a method type or as a plain type.
    # @rbs (String text) -> bool
    def method_type?(text)
      text.start_with?('(', '[', '{', '->') && !plain_type?(text)
    end

    # @rbs (String text) -> signature?
    def method_signature(text)
      method_type = RBS::Parser.parse_method_type(text, require_eof: true)
      method_type ? signature_of(method_type) : record_error(text)
    rescue RBS::ParsingError
      record_error(text)
    end

    # @rbs (RBS::MethodType method_type) -> signature
    def signature_of(method_type)
      function = method_type.type
      return untyped_signature(function) if function.is_a?(RBS::Types::UntypedFunction)

      function_types = RbsFunctionTypes.new(function)
      block = method_type.block
      { positional_types: function_types.positional_types,
        named_types: function_types.named_types,
        return_type: function_types.return_type,
        block_annotation: block && block_annotation_of(block.type) }
    end

    # A plain type such as `Proc` yields no types.
    #
    # @rbs (String text) -> BlockAnnotation?
    def block_annotation(text)
      method_type = RBS::Parser.parse_method_type(text, require_eof: true)
      method_type ? block_annotation_of(method_type.type) : plain_block_annotation(text)
    rescue RBS::ParsingError
      plain_block_annotation(text)
    end

    private

    # `(?) -> untyped` has no parameters to document.
    # @rbs (RBS::Types::UntypedFunction function) -> signature
    def untyped_signature(function)
      { positional_types: [], named_types: {}, block_annotation: nil,
        return_type: RbsTypeFormatter.format(function.return_type) }
    end

    # @rbs (RBS::Types::function function) -> BlockAnnotation
    def block_annotation_of(function)
      if function.is_a?(RBS::Types::UntypedFunction)
        return BlockAnnotation.new(yield_types: [],
                                   return_type: RbsTypeFormatter.format(function.return_type))
      end

      function_types = RbsFunctionTypes.new(function)
      BlockAnnotation.new(yield_types: function_types.yield_types,
                          return_type: function_types.return_type)
    end

    # @rbs (String text) -> BlockAnnotation?
    def plain_block_annotation(text)
      return record_error(text) unless RBS::Parser.parse_type(text, require_eof: true)

      BlockAnnotation.new(yield_types: [], return_type: nil)
    rescue RBS::ParsingError
      record_error(text)
    end

    # @rbs (String text) -> bool
    def plain_type?(text)
      !RBS::Parser.parse_type(text, require_eof: true).nil?
    rescue RBS::ParsingError
      false
    end

    # @rbs (String text) -> nil
    def record_error(text)
      @parse_errors << text
      nil
    end
  end
end
