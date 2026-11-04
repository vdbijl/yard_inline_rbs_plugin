# frozen_string_literal: true

module YardInlineRbs
  # Splits an annotation value into its type and description: `Integer -- the count`.
  # The type and the description may continue on the lines below, and the ` -- ` may also end a
  # line or start one. A line starting with `| (` starts another overload of a method type.
  class RbsDescription
    # Before a description: ` -- `, or ` --` at the end of a line.
    SEPARATOR = /\s--(?:\s|\z)/ #: Regexp

    # A line that starts another overload, such as `| (Float) -> Float`. A union type can
    # continue on a line starting with `| Float`, or `| [Float, String]`, so a line only starts an
    # overload after a line with the arrow of a method type.
    OVERLOAD = /\A\|\s*(?:[(\[{]|->)/ #: Regexp

    # The type of every overload of a method type, without the bars and the descriptions. A type
    # that is no overload, such as a union, is one.
    # @rbs (String? text) -> Array[String]
    def self.overloads(text)
      groups(text).each_with_index.map do |group, index|
        overload = group.join(' ')
        overload = overload.delete_prefix('|') if index.positive?
        overload.split(SEPARATOR).first.to_s.strip
      end
    end

    # The type of the first overload, and the description, if any.
    # @rbs (String? text) -> [String, String?]
    def self.split(text)
      type_string, description = groups(text).first.to_a.join(' ').split(SEPARATOR, 2)
      description = description.to_s.strip
      [type_string.to_s.strip, description.empty? ? nil : description]
    end

    # The lines of each overload: a line that starts another overload begins a new group.
    # @rbs (String? text) -> Array[Array[String]]
    def self.groups(text)
      method_type = false
      "#{text}\n".lines.map(&:strip).slice_before do |line|
        starts_overload = method_type && line.match?(OVERLOAD)
        method_type ||= line.include?('->')
        starts_overload
      end.to_a
    end
    private_class_method :groups
  end
end
