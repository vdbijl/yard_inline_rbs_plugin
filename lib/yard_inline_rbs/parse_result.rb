# frozen_string_literal: true

module YardInlineRbs
  # What an annotation types, as the warnings name it and InlineTypes records it.
  module Annotated
    RETURN_TYPE = 'the return type' #: String
    BLOCK = 'the block' #: String
    SIGNATURE = 'the signature' #: String

    # @rbs (String name) -> String
    def self.parameter(name)
      "parameter '#{name}'"
    end
  end

  # The annotations of one method, attribute or constant, collected while parsing. The first
  # annotation of a parameter, the return value or the block wins; a later one is recorded as a
  # duplicate. An annotation whose type could not be parsed does not count.
  class ParseResult
    # @rbs @signature_added: bool

    # The positional parameters, in Ruby order.
    attr_reader :positional_param_types #: Array[PositionalParamType]
    attr_reader :named_param_types #: Hash[String, NamedParamAnnotation]
    attr_reader :return_type #: String?
    attr_reader :return_description #: String?
    attr_reader :block_annotation #: BlockAnnotation?
    # The signatures of a method with overloads, which are no parameters of the method itself.
    attr_reader :overloads #: Array[signature]
    # The annotations that are not valid RBS.
    attr_reader :parse_errors #: Array[String]
    # The valid annotations the plugin does not use.
    attr_reader :unsupported_annotations #: Array[String]
    # What was annotated more than once, such as `parameter 'count'` or `the return type`.
    attr_reader :duplicate_annotations #: Array[String]

    # @rbs positional_param_types: Array[PositionalParamType]
    # @rbs named_param_types: Hash[String, NamedParamAnnotation]
    # @rbs return_type: String?
    # @rbs return_description: String?
    # @rbs block_annotation: BlockAnnotation?
    # @rbs return: void
    def initialize(positional_param_types: [], named_param_types: {}, return_type: nil,
                   return_description: nil, block_annotation: nil)
      @positional_param_types = positional_param_types
      @named_param_types = named_param_types
      @return_type = return_type
      @return_description = return_description
      @block_annotation = block_annotation
      @overloads = [] #: Array[signature]
      @parse_errors = []
      @unsupported_annotations = []
      @duplicate_annotations = []
      @signature_added = false
    end

    # @return [Boolean] Whether there is no type to apply.
    # @rbs () -> bool
    def empty?
      @positional_param_types.empty? && @named_param_types.empty? && @return_type.nil? &&
        @block_annotation.nil? && @overloads.empty?
    end

    # @rbs (String? type, ?String? description) -> void
    def add_return_type(type, description = nil)
      return if type.nil?
      return add_duplicate(Annotated::RETURN_TYPE) if @return_type

      @return_type = type
      @return_description = description
    end

    # @rbs (String name, NamedParamAnnotation annotation) -> void
    def add_named_param(name, annotation)
      return if annotation.type.nil?
      return add_duplicate(Annotated.parameter(name)) if @named_param_types.key?(name)

      @named_param_types[name] = annotation
    end

    # @rbs (BlockAnnotation? block_annotation) -> void
    def add_block(block_annotation)
      return if block_annotation.nil?
      return add_duplicate(Annotated::BLOCK) if @block_annotation

      @block_annotation = block_annotation
    end

    # Adds the signature of a method, or its overloads when it has several. Nothing for none.
    # @rbs (Array[signature] signatures) -> void
    def add_signatures(signatures)
      return add_signature(signatures.first) if signatures.size < 2

      add_overloads(signatures)
    end

    # Adds the signatures of a method with overloads, as TypeParser#method_signature returns them.
    # Like a second signature, a second set of overloads is one duplicate.
    # @rbs (Array[signature] signatures) -> void
    def add_overloads(signatures)
      return add_duplicate(Annotated::SIGNATURE) if @signature_added

      @signature_added = true
      @overloads.concat(signatures)
    end

    # Adds the parts of a method signature, as TypeParser#method_signature returns them, or
    # nothing for nil, an invalid signature. A second signature is one duplicate, not one for each
    # of its parts.
    # @rbs (signature? signature) -> void
    def add_signature(signature)
      return if signature.nil?
      return add_duplicate(Annotated::SIGNATURE) if @signature_added

      @signature_added = true
      @positional_param_types.concat(signature[:positional_types])
      signature[:named_types].each {|name, annotation| add_named_param(name, annotation)}
      add_return_type(signature[:return_type])
      add_block(signature[:block_annotation])
    end

    # Records that `annotated`, an Annotated value, was typed again.
    # @rbs (String annotated) -> void
    def add_duplicate(annotated)
      @duplicate_annotations << annotated
    end
  end

  # The type and description of a positional parameter.
  class PositionalParamType
    attr_reader :type #: String?
    attr_reader :name #: String?
    attr_reader :description #: String?

    # @rbs type: String?
    # @rbs name: String?
    # @rbs description: String?
    # @rbs return: void
    def initialize(type:, name: nil, description: nil)
      @type = type
      @name = name
      @description = description
    end
  end

  # The type and description of a keyword parameter, or of a splat. `rest` is true for a keyword
  # rest (`**options`), which collects the other keywords.
  class NamedParamAnnotation
    attr_reader :type #: String?
    attr_reader :description #: String?
    attr_reader :rest #: bool

    # @rbs type: String?
    # @rbs description: String?
    # @rbs rest: bool
    # @rbs return: void
    def initialize(type:, description: nil, rest: false)
      @type = type
      @description = description
      @rest = rest
    end
  end

  # The types a block yields and returns.
  class BlockAnnotation
    attr_reader :yield_types #: Array[String?]
    attr_reader :return_type #: String?

    # @rbs yield_types: Array[String?]
    # @rbs return_type: String?
    # @rbs return: void
    def initialize(yield_types:, return_type:)
      @yield_types = yield_types
      @return_type = return_type
    end
  end
end
