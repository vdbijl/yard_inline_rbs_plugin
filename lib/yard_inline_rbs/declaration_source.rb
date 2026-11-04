# frozen_string_literal: true

module YardInlineRbs
  # Where the declaration of a code object is, and its source line.
  class DeclarationSource
    # @rbs @object: YARD::CodeObjects::Base
    # @rbs @handler: YARD::Handlers::Base?
    # @rbs @first_line: String?

    # Forgets the files that were read. Called when the class loads, before each parse list,
    # because a file can change between two parses in a long-running process, and after it, to
    # free the memory.
    # @rbs () -> void
    def self.clear_cache
      @lines = {} #: Hash[String, Array[String]]
    end
    clear_cache

    # @rbs (String file) -> Array[String]
    def self.lines_of(file)
      @lines[file] ||= File.readlines(file)
    end

    # The handler is the one that parses the docstring, if any.
    # @rbs (YARD::CodeObjects::Base object, ?YARD::Handlers::Base? handler) -> void
    def initialize(object, handler = nil)
      @object = object
      @handler = handler
    end

    # The statement of the handler, else the first declaration outside a `.rbs` file. YARD's own
    # `object.file` is the first declaration with a comment: the `.rbs` file when it has a
    # comment, because the plugin parses the `.rbs` files first.
    # @rbs () -> [String, Integer?]?
    def location
      handler = @handler
      return [handler.parser.file, handler.statement.line] if handler

      files = @object.files
      files.find {|file, _line| !file.end_with?('.rbs')} || files.first
    end

    # The first line, for its trailing `#:` comment, or nil when that comment is the docstring:
    # without a comment above it, its annotation is already among the description lines.
    # @rbs () -> String?
    def trailing_comment_line
      first_line if !comment_on_declaration_line?
    end

    # YARD takes the trailing comment of a statement as the docstring of the next statement when
    # that has no comment above it, e.g. after a statement with a comment above it. The
    # annotations in such a comment belong to the earlier statement.
    # @rbs () -> bool
    def comment_of_earlier_statement?
      handler = @handler
      return false if handler.nil?

      comments_range = handler.statement.comments_range
      line = handler.statement.line
      return false if comments_range.nil? || line.nil? || comments_range.first >= line

      comment_line = file_line(handler.parser.file, comments_range.first)
      !comment_line.nil? && !comment_line.match?(/\A\s*#/)
    end

    # `lib/shop.rb:7`, or an empty string without a location.
    # @rbs () -> String
    def location_text
      location.to_a.compact.join(':')
    end

    # The first line. YARD's source of attr_* methods is synthetic, so the original file line
    # is read.
    # @rbs () -> String
    def first_line
      @first_line ||= original_line || @object.source.to_s.lines.first.to_s
    end

    # The `[String]` of `class StringArray < Array #[String]`.
    # @rbs () -> String?
    def superclass_type_application
      first_line[/\A\s*class\b[^#]*<[^#]*#(\[.+\])\s*\z/, 1]
    end

    private

    # @rbs () -> bool
    def comment_on_declaration_line?
      handler = @handler
      return false if handler.nil?

      statement = handler.statement
      comments_range = statement.comments_range
      !comments_range.nil? && comments_range.first == statement.line
    end

    # nil without a file, e.g. with YARD.parse_string, when the file cannot be read, or when it
    # has no such line.
    # @rbs () -> String?
    def original_line
      file, line = location
      file_line(file, line) if file && line
    end

    # nil when the file cannot be read, e.g. `(stdin)` with YARD.parse_string, or has no such line.
    # @rbs (String file, Integer line) -> String?
    def file_line(file, line)
      return if file == '(stdin)'

      self.class.lines_of(file)[line - 1]
    rescue SystemCallError
      nil
    end
  end
end
