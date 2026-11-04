# frozen_string_literal: true

module YardInlineRbs
  # Changes to YARD's handlers for `.rbs` files. They write tags from the signature text: unnamed
  # parameters get an empty name, generic types keep their RBS spelling, and the tags are lost
  # when a Ruby docstring is parsed afterwards. RbsFileTags writes the tags once all files are
  # parsed, so the method handler skips them, and the other handlers convert types with
  # RbsTypeFormatter. There are two patches because the attribute and constant handlers write
  # their tags inline, so only the type conversion can change them. Both rely on internals of
  # YARD 0.9.45; the spec of `.install` fails when a YARD upgrade renames them.
  module RbsHandlerPatches
    # Applies both patches. The prepends live in a method, because YARD would read them as mixins
    # of an unknown class when it documents this gem.
    # @rbs () -> void
    def self.install
      YARD::Handlers::RBS::MethodHandler.prepend(MethodTags)
      YARD::Handlers::RBS::MethodHandler.singleton_class.prepend(TypeConversion)
    end

    # Prepended to YARD::Handlers::RBS::MethodHandler.
    module MethodTags
      private

      # @rbs (YARD::CodeObjects::MethodObject _object, Array[String]? _signatures) -> void
      def apply_signature_tags(_object, _signatures); end
    end

    # Prepended to the singleton class of YARD::Handlers::RBS::MethodHandler.
    module TypeConversion
      # @rbs (String rbs) -> Array[String]
      def rbs_type_to_yard_types(rbs)
        rbs_type = RBS::Parser.parse_type(rbs, require_eof: true)
        return super if rbs_type.nil?

        [RbsTypeFormatter.format(rbs_type)]
      rescue RBS::ParsingError
        super
      end
    end
  end
end
