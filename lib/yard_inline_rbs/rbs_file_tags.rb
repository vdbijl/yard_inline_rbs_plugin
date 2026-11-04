# frozen_string_literal: true

module YardInlineRbs
  # Writes the types declared in `.rbs` files onto the YARD objects of the same methods,
  # attributes and constants. This runs after all files are parsed, and only adds the tags that
  # are missing, so docstrings and inline annotations win.
  class RbsFileTags
    # @rbs @path: String

    # The YARD path separators of each kind of RBS member.
    SEPARATORS = {
      instance: %w[#], singleton: %w[.], singleton_instance: %w[# .]
    }.freeze #: Hash[Symbol, Array[String]]

    # Moves the `.rbs` files before the Ruby files, in place. YARD replaces the whole docstring
    # of an object whenever it parses a comment later, so the Ruby docstrings, with their
    # description and inline annotations, must be parsed last. YARD has no option for the order.
    # @rbs (Array[String] files) -> void
    def self.parse_rbs_first(files)
      files.replace(files.partition {|file| file.end_with?('.rbs')}.flatten)
    end

    # @rbs (Array[String] files) -> void
    def self.apply(files)
      files.grep(/\.rbs\z/).each {|file| new(file).apply}
    end

    # @rbs (String path) -> void
    def initialize(path)
      @path = path
    end

    # @rbs () -> void
    def apply
      declarations.each {|declaration| apply_declaration(declaration, '')}
    end

    private

    # A file that cannot be read or parsed is skipped with a warning, so it does not stop the
    # documentation of the other files. Only this step is rescued, so a bug in the tagging is not.
    # @rbs () -> Array[RBS::AST::Declarations::t]
    def declarations
      buffer = RBS::Buffer.new(name: Pathname(@path), content: File.read(@path))
      RBS::Parser.parse_signature(buffer).last
    rescue RBS::ParsingError, ArgumentError, SystemCallError => e
      YardInlineRbs.warn("#{@path}: #{e.message}")
      []
    end

    # @rbs (RBS::AST::Declarations::t | RBS::AST::Members::t declaration, String namespace)
    #   -> void
    def apply_declaration(declaration, namespace)
      case declaration
      when RBS::AST::Declarations::Class, RBS::AST::Declarations::Module
        apply_members(declaration.members, qualify(namespace, declaration.name))
      when RBS::AST::Declarations::Constant
        tag_object(qualify(namespace, declaration.name)) {|tags| tags.type(declaration.type)}
      end
    end

    # @rbs (Array[RBS::AST::Members::t | RBS::AST::Declarations::t] members, String namespace)
    #   -> void
    def apply_members(members, namespace)
      members.each do |member|
        case member
        when RBS::AST::Members::MethodDefinition then apply_method(member, namespace)
        when RBS::AST::Members::AttrReader, RBS::AST::Members::AttrWriter,
             RBS::AST::Members::AttrAccessor then apply_attribute(member, namespace)
        else apply_declaration(member, namespace)
        end
      end
    end

    # @rbs (RBS::AST::Members::MethodDefinition member, String namespace) -> void
    def apply_method(member, namespace)
      method_types = member.overloads.map(&:method_type)
      tag_members(namespace, member.name.to_s, member.kind) {|tags| tags.method_types(method_types)}
    end

    # @rbs (RBS::AST::Members::AttrReader | RBS::AST::Members::AttrWriter |
    #   RBS::AST::Members::AttrAccessor member, String namespace) -> void
    def apply_attribute(member, namespace)
      attribute_names(member).each do |name|
        tag_members(namespace, name, member.kind) {|tags| tags.type(member.type)}
      end
    end

    # @rbs (RBS::AST::Members::AttrReader | RBS::AST::Members::AttrWriter |
    #   RBS::AST::Members::AttrAccessor member) -> Array[String]
    def attribute_names(member)
      name = member.name.to_s
      case member
      when RBS::AST::Members::AttrReader then [name]
      when RBS::AST::Members::AttrWriter then ["#{name}="]
      else [name, "#{name}="]
      end
    end

    # @rbs (String namespace, String name, Symbol kind) { (MemberTags) -> void } -> void
    def tag_members(namespace, name, kind, &)
      SEPARATORS.fetch(kind).each {|separator| tag_object("#{namespace}#{separator}#{name}", &)}
    end

    # @rbs (String path) { (MemberTags) -> void } -> void
    def tag_object(path)
      object = YARD::Registry.at(path)
      return if object.nil?

      member_tags = MemberTags.new(object)
      yield member_tags
      # Only an inline annotation makes a duplicate, so its location is known.
      AnnotationWarnings.new(InlineTypes.location(object).to_s)
                        .report_rbs_file_duplicates(member_tags.duplicate_annotations, @path)
    end

    # @rbs (String namespace, RBS::TypeName name) -> String
    def qualify(namespace, name)
      return name.to_s.delete_prefix('::') if name.absolute?

      [namespace, name.to_s].reject(&:empty?).join('::')
    end
  end
end
