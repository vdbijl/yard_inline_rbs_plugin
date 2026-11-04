# frozen_string_literal: true

module YardInlineRbs
  # Collects the RBS annotations of `@rbs` tags, `#:` description lines and a trailing `#:`.
  class RbsCommentParser
    # @rbs @rbs_tag_texts: Array[String]
    # @rbs @inline_annotations: Array[String]
    # @rbs @source_line: String?
    # @rbs @result: ParseResult
    # @rbs @types: TypeParser

    # @rbs rbs_tag_texts: Array[String] -- The texts of the `@rbs` tags, which YARD strips.
    # @rbs inline_annotations: Array[String]
    # @rbs source_line: String? -- The declaration line, for a trailing `#:`; nil to skip it.
    # @rbs return: void
    def initialize(rbs_tag_texts, inline_annotations, source_line)
      @rbs_tag_texts = rbs_tag_texts
      @inline_annotations = inline_annotations
      @source_line = source_line
    end

    # @rbs () -> ParseResult
    def parse
      @result = ParseResult.new
      @types = TypeParser.new(@result.parse_errors)
      inline = InlineAnnotations.new(@types, @result)

      @rbs_tag_texts.each {|text| process_rbs_tag(text)}
      @inline_annotations.each {|line| inline.process_line(line)}
      source_line = @source_line
      inline.process_trailing(source_line) if source_line

      @result
    end

    private

    # A description after `--` would make a plain type, such as `[Integer, String] -- The pair.`,
    # look like a method type, so only the type decides.
    # @rbs (String text) -> void
    def process_rbs_tag(text)
      return if type_checker_only_annotation?(text)
      return process_ivar_annotation(text) if text.start_with?('@')
      return process_block_annotation(text) if text.start_with?('&')
      return process_splat_annotation(text) if text.match?(/\A\*{1,2}\w*:/)
      return record_unsupported(text) if structural_rbs_annotation?(text)

      type_str, = RbsDescription.split(text)
      return process_method_signature(text) if @types.method_type?(type_str)

      process_named_or_standalone(text)
    end

    # @rbs (String text) -> void
    def process_named_or_standalone(text)
      if (match = text.match(/\A(\w+):(?!:)\s*(.+)/m))
        process_named_annotation(match[1], match[2])
      else
        process_standalone_return_type(text)
      end
    end

    # @rbs (String text) -> void
    def record_unsupported(text)
      @result.unsupported_annotations << text
    end

    # Annotations for the type checker only: `skip`, `...` and `module-self:`, and `override`,
    # `generic`, `inherits` and `use` of the rbs-inline gem.
    # @rbs (String text) -> bool
    def type_checker_only_annotation?(text)
      %w[skip ... override].include?(text) ||
        text.start_with?('module-self:', 'generic ', 'inherits ', 'use ')
    end

    # An unnamed splat (`*: Type`) is recorded as '*' or '**'; TagInjector resolves the name.
    # @rbs (String text) -> void
    def process_splat_annotation(text)
      match = text.match(/\A(\*{1,2})(\w*):\s*(.+)/m)
      return @result.parse_errors << text unless match

      stars = match[1].to_s
      name = match[2].to_s
      type_str, description = RbsDescription.split(match[3])
      yard_type = @types.type(type_str)
      @result.add_named_param(name.empty? ? stars : name,
                              NamedParamAnnotation.new(type: yard_type, description: description))
    end

    # Declarations (def, class, end, attr_*) describe structure, not types.
    # @rbs (String text) -> bool
    def structural_rbs_annotation?(text)
      text == 'end' ||
        text.start_with?('def ', 'class ', 'attr_reader ', 'attr_writer ', 'attr_accessor ')
    end

    # The `?` of an optional block (`&block: ? () -> void`) is ignored.
    # @rbs (String text) -> void
    def process_block_annotation(text)
      match = text.match(/\A&\w*:\s*(.+)/m)
      return @result.parse_errors << text unless match

      type_str, = RbsDescription.split(match[1])
      @result.add_block(@types.block_annotation(type_str.delete_prefix('?')))
    end

    # @rbs (String text) -> void
    def process_standalone_return_type(text)
      type_str, = RbsDescription.split(text)
      @result.add_return_type(@types.type(type_str))
    end

    # @rbs (String text) -> void
    def process_ivar_annotation(text)
      match = text.match(/\A@@?(\w+):\s*(.+)/m)
      return unless match

      type_str, = RbsDescription.split(match[2])
      @types.type(type_str) # An invalid type is reported, although the annotation is not used.
      @result.unsupported_annotations << text
    end

    # @rbs (String key, String value) -> void
    def process_named_annotation(key, value)
      type_str, description = RbsDescription.split(value)
      yard_type = @types.type(type_str)

      if key == 'return'
        @result.add_return_type(yard_type, description)
      else
        @result.add_named_param(key, NamedParamAnnotation.new(type: yard_type,
                                                              description: description))
      end
    end

    # A signature with overloads that cannot all be parsed is documented with the ones that can.
    # @rbs (String text) -> void
    def process_method_signature(text)
      overloads = RbsDescription.overloads(text)
      @result.add_signatures(overloads.filter_map {|overload| @types.method_signature(overload)})
    end
  end
end
