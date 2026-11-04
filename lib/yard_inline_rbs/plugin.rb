# frozen_string_literal: true

YARD::Tags::Library.define_tag('RBS annotation', :rbs)

YARD::DocstringParser.after_parse do |parser|
  YardInlineRbs::TagInjector.new(parser).inject
end

YardInlineRbs::RbsHandlerPatches.install

# Also runs for YARD.parse_string. A callback that returns false would skip the file.
YARD::Parser::SourceParser.before_parse_file do |_parser|
  YardInlineRbs::AnnotationWarnings.clear_logged
end

YARD::Parser::SourceParser.before_parse_list do |files, _globals|
  YardInlineRbs::DeclarationSource.clear_cache
  YardInlineRbs::RbsFileTags.parse_rbs_first(files)
end

YARD::Parser::SourceParser.after_parse_list do |files, _globals|
  YardInlineRbs::RbsFileTags.apply(files)
  YardInlineRbs::DeclarationSource.clear_cache # Frees the lines of all files.
end
