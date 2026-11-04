# frozen_string_literal: true

module YardInlineRbs
  # Warns about annotations the plugin cannot use, once per location. YARD parses some docstrings
  # more than once: an attribute with its default docstring, both methods of an attr_accessor, and
  # a trailing comment that is also the docstring.
  class AnnotationWarnings
    # @rbs @location: String

    # The warnings that were logged, so each is logged once.
    LOGGED = Set.new #: Set[String]

    # Forgets the warnings that were logged. Called before each file is parsed: the location of a
    # warning includes the file, so a file parsed again warns again.
    # @rbs () -> nil
    def self.clear_logged
      LOGGED.clear
      nil
    end

    # The location is that of the declaration, such as `lib/shop.rb:7`.
    # @rbs (String location) -> void
    def initialize(location)
      @location = location
    end

    # @rbs (ParseResult result) -> void
    def report(result)
      warn_each(result.parse_errors, 'could not parse RBS type')
      warn_each(result.unsupported_annotations, 'unsupported RBS annotation')
      warn_duplicates(result.duplicate_annotations)
    end

    # Types that both an inline annotation and the `.rbs` file at `rbs_path` declare.
    # @rbs (Array[String] duplicate_annotations, String rbs_path) -> void
    def report_rbs_file_duplicates(duplicate_annotations, rbs_path)
      warn_duplicates(duplicate_annotations, ", one in #{rbs_path}")
    end

    private

    # @rbs (Array[String] duplicate_annotations, ?String suffix) -> void
    def warn_duplicates(duplicate_annotations, suffix = '')
      duplicate_annotations.each {|annotated| log("two RBS annotations for #{annotated}#{suffix}")}
    end

    # @rbs (Array[String] annotations, String problem) -> void
    def warn_each(annotations, problem)
      annotations.each {|annotation| log("#{problem} '#{annotation}'")}
    end

    # @rbs (String problem) -> void
    def log(problem)
      message = "#{@location}: #{problem}"
      YardInlineRbs.warn(message) if LOGGED.add?(message)
    end
  end
end
