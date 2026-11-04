# frozen_string_literal: true

module YardInlineRbs
  # Gives a registered code object the `tags` and `tags=` of a DocstringParser. The docstring
  # of an object returns a copy of its tags, so changes must go through its own mutators.
  class ObjectTags
    attr_reader :object #: YARD::CodeObjects::Base

    # @rbs (YARD::CodeObjects::Base object) -> void
    def initialize(object)
      @object = object
    end

    # @rbs () -> Array[YARD::Tags::Tag]
    def tags
      @object.tags
    end

    # @rbs (Array[YARD::Tags::Tag] new_tags) -> void
    def tags=(new_tags)
      docstring = @object.docstring
      docstring.delete_tag_if {true}
      new_tags.each {|tag| docstring.add_tag(tag)}
    end
  end
end
