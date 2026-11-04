# frozen_string_literal: true

module YardInlineRbs
  # Injects typed tags from the RBS annotations of a YARD DocstringParser. RBS types override
  # YARD types. The annotations are always stripped from the docstring, also when invalid: the
  # warning reports the problem, and the raw text would only clutter the documentation.
  class TagInjector
    # @rbs @parser: YARD::DocstringParser

    # @rbs (YARD::DocstringParser parser) -> void
    def initialize(parser)
      @parser = parser
    end

    # @rbs () -> void
    def inject
      object = @parser.object
      return if object.nil?

      source = DeclarationSource.new(object, @parser.handler)
      inline_annotations = collect_inline_annotations
      rbs_tag_texts = collect_rbs_tag_texts
      result = parse_rbs_annotations(source, rbs_tag_texts, inline_annotations)

      annotated = inline_annotations.any? || rbs_tag_texts.any?
      record_and_report(object, source, result, apply_result(source, result, inline_annotations))
      keep_previous_description(object) if annotated && @parser.text.empty?
    end

    private

    # Records what the annotations typed, for RbsFileTags, and warns about their problems. The
    # warnings come after the tags are applied, which finds more duplicates.
    # @rbs (YARD::CodeObjects::Base object, DeclarationSource source, ParseResult result,
    #   Array[String] typed) -> void
    def record_and_report(object, source, result, typed)
      location = source.location_text
      InlineTypes.record(object, typed, location)
      AnnotationWarnings.new(location).report(result)
    end

    # @rbs (DeclarationSource source, Array[String] rbs_tag_texts, Array[String] inline_annotations)
    #   -> ParseResult
    def parse_rbs_annotations(source, rbs_tag_texts, inline_annotations)
      RbsCommentParser.new(rbs_tag_texts, own_annotations(source, inline_annotations),
                           source.trailing_comment_line).parse
    end

    # The `#:` lines of a comment that YARD took from an earlier statement belong to that
    # statement, so they are skipped; they are still removed from the description.
    # @rbs (DeclarationSource source, Array[String] inline_annotations) -> Array[String]
    def own_annotations(source, inline_annotations)
      return [] if source.comment_of_earlier_statement?

      inline_annotations
    end

    # The tags are only rewritten when there is a type to apply.
    # @rbs (DeclarationSource source, ParseResult result, Array[String] inline_annotations)
    #   -> Array[String]
    # @return [Array<String>] What the annotations typed, such as `the return type`.
    def apply_result(source, result, inline_annotations)
      clean_description(source, inline_annotations)
      remove_rbs_tags
      return [] if result.empty?

      applier = ResultApplier.new(@parser)
      applier.apply(result)
      applier.typed
    end

    # YARD replaces the docstring of an object with each comment it parses, also with a comment
    # that only holds annotations. The previous description, such as that of a `.rbs`
    # declaration, is still on the object while the new one is parsed.
    # @rbs (YARD::CodeObjects::Base object) -> void
    def keep_previous_description(object)
      @parser.text = object.docstring.to_s
    end

    # @rbs () -> Array[String]
    def collect_rbs_tag_texts
      @parser.tags.select {|tag| tag.tag_name == 'rbs'}.map(&:text)
    end

    # The description lines of each `#:` annotation: the line starting with `:` and the indented
    # lines below it, on which a signature can continue.
    # @rbs () -> Array[String]
    def collect_inline_annotations
      annotations = [] #: Array[String]
      continued = false
      @parser.text.each_line do |line|
        continuation = continued && line.match?(/\A\s+\S/)
        annotations << line if inline_annotation?(line)
        annotations << "#{annotations.pop}#{line}" if continuation
        continued = continuation || inline_annotation?(line)
      end
      annotations
    end

    # `: Type`, or only `:`, which is reported as an invalid type.
    # @rbs (String line) -> bool
    def inline_annotation?(line)
      stripped = line.strip
      stripped == ':' || stripped.start_with?(': ')
    end

    # @rbs (DeclarationSource source, Array[String] inline_annotations) -> void
    def clean_description(source, inline_annotations)
      annotation_lines = inline_annotations.flat_map(&:lines).map(&:strip)
      application = source.superclass_type_application
      annotation_lines << application if application
      return if annotation_lines.empty?

      @parser.text = @parser.text.lines
                            .reject {|line| annotation_lines.include?(line.strip)}
                            .join
                            .strip
    end

    # @rbs () -> void
    def remove_rbs_tags
      @parser.tags = @parser.tags.reject {|tag| tag.tag_name == 'rbs'}
    end
  end
end
