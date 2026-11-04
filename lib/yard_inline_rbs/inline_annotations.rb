# frozen_string_literal: true

module YardInlineRbs
  # Reads the inline `#:` annotations. Values already in the result win, because `@rbs`
  # tags take precedence; the result records the duplicates.
  class InlineAnnotations
    # @rbs @types: TypeParser
    # @rbs @result: ParseResult

    # @rbs (TypeParser types, ParseResult result) -> void
    def initialize(types, result)
      @types = types
      @result = result
    end

    # A description line starting with `:`, with the indented lines below it. Unlike `@rbs`, a
    # `#:` signature cannot have overloads: Steep rejects it.
    # @rbs (String line) -> void
    def process_line(line)
      annotation = line.strip.delete_prefix(':')
      if overloads?(annotation)
        @result.parse_errors << annotation.lines.map(&:strip).join(' ')
      else
        annotate(annotation) {|type_str| @result.add_signature(@types.method_signature(type_str))}
      end
    end

    # The declaration line may end in `#: Type`.
    # @rbs (String source_line) -> void
    def process_trailing(source_line)
      match = source_line.match(/(?:\A|\s)#:\s*(.+)$/)
      return unless match

      annotate(match[1]) do |type_str|
        signature = @types.method_signature(type_str)
        @result.add_return_type(signature[:return_type]) if signature
      end
    end

    private

    # @rbs (String annotation) -> bool
    def overloads?(annotation)
      RbsDescription.overloads(annotation).size > 1
    end

    # `class-alias` and `module-alias` declare a type name, not a type.
    # @rbs (String type_str) -> bool
    def alias_annotation?(type_str)
      type_str.match?(/\A(class|module)-alias\b/)
    end

    # Yields method types; any other type is the return type.
    # @rbs (String annotation) { (String) -> void } -> void
    def annotate(annotation)
      type_str, = RbsDescription.split(annotation)
      return if alias_annotation?(type_str)
      return yield(type_str) if @types.method_type?(type_str)

      @result.add_return_type(@types.type(type_str))
    end
  end
end
