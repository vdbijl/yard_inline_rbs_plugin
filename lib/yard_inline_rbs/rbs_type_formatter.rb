# frozen_string_literal: true

module YardInlineRbs
  # Converts RBS types into YARD type strings. RBS `bool` becomes YARD's `Boolean`.
  class RbsTypeFormatter
    BASE_TYPE_STRINGS = { #: Hash[Class, String]
      RBS::Types::Bases::Nil => 'nil',
      RBS::Types::Bases::Void => 'void',
      RBS::Types::Bases::Bool => 'Boolean',
      RBS::Types::Bases::Any => 'untyped',
      RBS::Types::Bases::Top => 'top',
      RBS::Types::Bases::Bottom => 'bot',
      RBS::Types::Bases::Self => 'self'
    }.freeze

    # @rbs (RBS::Types::t rbs_type) -> String
    def self.format(rbs_type)
      BASE_TYPE_STRINGS[rbs_type.class] || format_structured(rbs_type)
    end

    # A comma-separated YARD type list.
    # @rbs (RBS::Types::t rbs_type) -> String
    def self.format_structured(rbs_type)
      case rbs_type
      when RBS::Types::Optional then "#{format(rbs_type.type)}, nil"
      when RBS::Types::Union then format_list(rbs_type.types)
      when RBS::Types::Intersection then format_list(rbs_type.types, ' & ')
      else format_collection(rbs_type)
      end
    end
    private_class_method :format_structured

    # @rbs (RBS::Types::t rbs_type) -> String
    def self.format_collection(rbs_type)
      case rbs_type
      when RBS::Types::Proc then 'Proc'
      when RBS::Types::Tuple then format_tuple(rbs_type)
      when RBS::Types::Record then format_record(rbs_type)
      else format_named(rbs_type)
      end
    end
    private_class_method :format_collection

    # @rbs (Array[RBS::Types::t] types, ?String separator) -> String
    def self.format_list(types, separator = ', ')
      types.map {|type| format(type)}.join(separator)
    end
    private_class_method :format_list

    # `Array(Integer, String)`, YARD's notation for an array of fixed length, or `Array` for `[]`.
    # @rbs (RBS::Types::Tuple rbs_type) -> String
    def self.format_tuple(rbs_type)
      return 'Array' if rbs_type.types.empty?

      "Array(#{rbs_type.types.map {|type| format_element(type)}.join(', ')})"
    end
    private_class_method :format_tuple

    # An optional or a union is a list of types itself, so it is grouped in a tuple:
    # `Array((Integer, nil), String)`.
    # @rbs (RBS::Types::t type) -> String
    def self.format_element(type)
      case type
      when RBS::Types::Optional, RBS::Types::Union then "(#{format(type)})"
      else format(type)
      end
    end
    private_class_method :format_element

    # `Hash{Symbol => String, Integer}` for `{ name: String, age: Integer }`: the names of the keys
    # are lost, YARD has no notation for them. `Hash` for `{}`.
    # @rbs (RBS::Types::Record rbs_type) -> String
    def self.format_record(rbs_type)
      fields = rbs_type.all_fields
      return 'Hash' if fields.empty?

      keys = fields.keys.map(&:class).uniq.join(', ')
      values = fields.values.map {|type, _required| format(type)}.uniq.join(', ')
      "Hash{#{keys} => #{values}}"
    end
    private_class_method :format_record

    # Literals and type variables keep their RBS spelling, such as `:ok` and `T`.
    # @rbs (RBS::Types::t rbs_type) -> String
    def self.format_named(rbs_type)
      case rbs_type
      when RBS::Types::ClassInstance, RBS::Types::Alias, RBS::Types::Interface
        format_class_instance(rbs_type)
      else rbs_type.to_s
      end
    end
    private_class_method :format_named

    # A class, alias or interface, with its namespace and type arguments: `Shop::path`,
    # `_Each<Integer>`.
    # @rbs (RBS::Types::ClassInstance | RBS::Types::Alias | RBS::Types::Interface rbs_type)
    #   -> String
    def self.format_class_instance(rbs_type)
      name = rbs_type.name.to_s.delete_prefix('::')
      return name if rbs_type.args.empty?
      return format_hash_instance(rbs_type) if name == 'Hash' && rbs_type.args.length == 2

      "#{name}<#{format_list(rbs_type.args)}>"
    end
    private_class_method :format_class_instance

    # @rbs (RBS::Types::ClassInstance | RBS::Types::Alias | RBS::Types::Interface rbs_type)
    #   -> String
    def self.format_hash_instance(rbs_type)
      "Hash{#{format(rbs_type.args[0])} => #{format(rbs_type.args[1])}}"
    end
    private_class_method :format_hash_instance
  end
end
