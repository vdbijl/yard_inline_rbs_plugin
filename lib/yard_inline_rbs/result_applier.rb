# frozen_string_literal: true

module YardInlineRbs
  # Injects the typed tags of a ParseResult into a tag target: a YARD DocstringParser or an
  # ObjectTags. RBS types replace existing ones, unless `keep_existing` is set. A parameter that
  # a named and a positional annotation both type keeps the first, the named one, and is recorded
  # in the result as a duplicate. With `keep_existing`, a kept tag that an inline annotation
  # typed is a duplicate too.
  class ResultApplier
    # @rbs @target: YARD::DocstringParser | ObjectTags
    # @rbs @object: YARD::CodeObjects::Base
    # @rbs @keep_existing: bool
    # @rbs @parameter_names: ParameterNames
    # @rbs @tags: Array[YARD::Tags::Tag]
    # @rbs @result: ParseResult

    # What the last #apply typed, such as `parameter 'count'` and `the return type`.
    attr_reader :typed #: Array[String]

    # @rbs (YARD::DocstringParser | ObjectTags target, ?keep_existing: bool) -> void
    def initialize(target, keep_existing: false)
      @target = target
      # YARD types the object of a parser as optional, but TagInjector skips a parser without one.
      @object = target.object #: YARD::CodeObjects::Base
      @keep_existing = keep_existing
      @parameter_names = ParameterNames.new(@object)
      @typed = []
    end

    # @rbs (ParseResult result) -> void
    def apply(result)
      @result = result
      @typed = []
      @tags = @target.tags
      inject_overload_tags(result.overloads)
      inject_param_tags
      inject_return_or_writer_param_tag(result.return_type, result.return_description)
      inject_yield_tags(result.block_annotation)
      @target.tags = @tags
    end

    private

    # The @overload tags of the docstring win: they are written by hand. A declaration that an
    # inline annotation already typed adds none.
    # @rbs (Array[signature] signatures) -> void
    def inject_overload_tags(signatures)
      return if signatures.empty? || @tags.any? {|tag| tag.tag_name == 'overload'}
      if @keep_existing && InlineTypes.any?(@object)
        return @result.add_duplicate(Annotated::SIGNATURE)
      end

      @tags += signatures.map do |signature|
        YARD::Tags::OverloadTag.new(:overload, OverloadText.new(@object.name, signature).to_s)
      end
      @typed |= [Annotated::SIGNATURE]
    end

    # @rbs () -> void
    def inject_param_tags
      @result.named_param_types.each do |name, annotation|
        inject_param_tag(@parameter_names.resolve_splat(name), annotation.type,
                         annotation.description)
      end
      inject_positional_param_tags(@result.positional_param_types)
      sort_param_tags
    end

    # YARD renders @param tags in tag order. Unknown names keep their order, at the end.
    # @rbs () -> void
    def sort_param_tags
      tag_order = @parameter_names.tag_order
      param_tags, other_tags = @tags.partition {|tag| tag.tag_name == 'param'}
      @tags = other_tags + param_tags.sort_by.with_index do |tag, index|
        [tag_order.index(tag.name) || tag_order.size, index]
      end
    end

    # The Ruby names win, because Steep does not check RBS parameter names. Without Ruby
    # parameters, e.g. a method that only exists in a `.rbs` file, the RBS names are used, and
    # the unnamed parameters are called arg0, arg1, ...
    # @rbs (Array[PositionalParamType] positional_param_types) -> void
    def inject_positional_param_tags(positional_param_types)
      names = @parameter_names.positional
      positional_param_types.each_with_index do |param, index|
        name = if @parameter_names.empty?
                 param.name || ParameterNames.placeholder(index)
               else
                 names[index]
               end
        inject_param_tag(name, param.type, param.description) if name
      end
    end

    # @rbs (String name, String? yard_type, String? description) -> void
    def inject_param_tag(name, yard_type, description)
      return if yard_type.nil?

      annotated = Annotated.parameter(name)
      return @result.add_duplicate(annotated) if @typed.include?(annotated)

      replace_tag('param', name, [yard_type], description, annotated)
    end

    # @rbs (BlockAnnotation? block_annotation) -> void
    def inject_yield_tags(block_annotation)
      return if block_annotation.nil?

      replace_tag('yield', nil, block_annotation.yield_types, nil, Annotated::BLOCK)
      return_type = block_annotation.return_type
      replace_tag('yieldreturn', nil, [return_type], nil, Annotated::BLOCK) if return_type
    end

    # Replaces the tags of `tag_name` and `name` with one of `types`, and records `annotated` as
    # typed. The description of the annotation wins, else that of the tag it replaces. A kept tag
    # stays as it is, and is a duplicate when an inline annotation typed it.
    # @rbs (String tag_name, String? name, Array[String?] types, String? description,
    #   String annotated) -> void
    def replace_tag(tag_name, name, types, description, annotated)
      replaced, other_tags = @tags.partition {|tag| tag.tag_name == tag_name && tag.name == name}
      return record_kept(annotated) if kept?(replaced)

      text = description || replaced.first&.text || ''
      @tags = other_tags + [YARD::Tags::Tag.new(tag_name, text, types, name)]
      @typed |= [annotated]
    end

    # A writer's type describes its parameter. `writer?` is not set yet in after_parse. A
    # signature such as `(Symbol, Integer) -> Integer` types the value twice, which is no duplicate.
    # @rbs (String? yard_type, String? description) -> void
    def inject_return_or_writer_param_tag(yard_type, description)
      return unless yard_type

      if @object.name.match?(/\A(\w+|\[\])=\z/)
        value = value_parameter_name
        inject_param_tag(value, yard_type, description) if @typed.none?(Annotated.parameter(value))
      else
        replace_tag('return', nil, [yard_type], description, Annotated::RETURN_TYPE)
      end
    end

    # The parameter that a writer sets: the last one, as in `[]=(key, value)`. Without Ruby
    # parameters, the one that the last annotated parameter was tagged as.
    # @rbs () -> String
    def value_parameter_name
      @parameter_names.positional.last || annotated_value_name || 'value'
    end

    # @rbs () -> String?
    def annotated_value_name
      params = @result.positional_param_types
      last = params.last
      return if last.nil?

      last.name || ParameterNames.placeholder(params.size - 1)
    end

    # With keep_existing, a tag that already has types is kept; one with only a description gets
    # the RBS type.
    # @rbs (Array[YARD::Tags::Tag] tags) -> bool
    def kept?(tags)
      @keep_existing && tags.any? {|tag| tag.types.to_a.any?}
    end

    # @rbs (String annotated) -> void
    def record_kept(annotated)
      @result.add_duplicate(annotated) if InlineTypes.typed?(@object, annotated)
    end
  end
end
