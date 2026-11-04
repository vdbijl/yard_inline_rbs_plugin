# frozen_string_literal: true

module YardInlineRbs
  # Tags a registered YARD object with the types of an RBS declaration. Tags that are already
  # there win, so a Ruby docstring or an inline annotation beats a `.rbs` declaration.
  class MemberTags
    # @rbs @object: YARD::CodeObjects::Base
    # @rbs @tags: ObjectTags
    # @rbs @types: TypeParser

    # What an inline annotation typed as well, such as `the return type`.
    attr_reader :duplicate_annotations #: Array[String]

    # @rbs (YARD::CodeObjects::Base object) -> void
    def initialize(object)
      @object = object
      @tags = ObjectTags.new(object)
      @types = TypeParser.new([])
      @duplicate_annotations = []
    end

    # A method with several signatures gets an @overload tag for each.
    # @rbs (Array[RBS::MethodType] method_types) -> void
    def method_types(method_types)
      signatures = method_types.map {|method_type| @types.signature_of(method_type)}
      apply(ParseResult.new.tap {|result| result.add_signatures(signatures)})
    end

    # The type of an attribute or constant.
    # @rbs (RBS::Types::t type) -> void
    def type(type)
      apply(ParseResult.new.tap {|result| result.add_return_type(RbsTypeFormatter.format(type))})
    end

    private

    # @rbs (ParseResult result) -> void
    def apply(result)
      ResultApplier.new(@tags, keep_existing: true).apply(result)
      @duplicate_annotations.concat(result.duplicate_annotations)
    end
  end
end
