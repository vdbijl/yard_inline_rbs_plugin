# frozen_string_literal: true

# Runs YARD in the current directory as `yard doc` does, with .yardopts and its plugins, but
# without writing anything. Then prints the docstring and tags of every object. The arguments are
# passed to YARD, so they can replace the files of .yardopts. spec/yard_inline_rbs_fixture_projects_spec.rb runs
# this script in a subprocess inside a fixture project.
require 'yard'

YARD::CLI::Yardoc.run('--no-save', '--no-output', '--no-stats', *ARGV)
YARD::Registry.all.sort_by(&:path).each do |object|
  puts object.path
  object.docstring.to_s.each_line {|line| puts "  #{line.chomp}"}
  object.tags.each do |tag|
    puts ["  @#{tag.tag_name}", tag.name, tag.types && "[#{tag.types.join(', ')}]", tag.text]
      .compact.reject(&:empty?).join(' ')
  end
end
