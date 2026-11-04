# frozen_string_literal: true

require 'rbs'

RSpec.describe YardInlineRbs::RbsTypeFormatter do
  def parse_type(string)
    RBS::Parser.parse_type(string, require_eof: true)
  end

  def parse_method_type(string)
    RBS::Parser.parse_method_type(string)
  end

  def format_rbs(string)
    described_class.format(parse_type(string))
  end

  describe '.format' do
    context 'with an alias type' do
      it 'returns path for path' do
        expect(format_rbs('path')).to eq('path')
      end

      it 'returns Shop::path for Shop::path' do
        expect(format_rbs('Shop::path')).to eq('Shop::path')
      end

      it 'returns Foo::bar for ::Foo::bar' do
        expect(format_rbs('::Foo::bar')).to eq('Foo::bar')
      end

      it 'returns list<Integer> for list[Integer]' do
        expect(format_rbs('list[Integer]')).to eq('list<Integer>')
      end
    end

    context 'with an interface type' do
      it 'returns _Each<Integer> for _Each[Integer]' do
        expect(format_rbs('_Each[Integer]')).to eq('_Each<Integer>')
      end

      it 'returns _Each for _Each' do
        expect(format_rbs('_Each')).to eq('_Each')
      end
    end

    context 'with a singleton type' do
      it 'returns singleton(String) for singleton(String)' do
        expect(format_rbs('singleton(String)')).to eq('singleton(String)')
      end
    end

    context 'with base types' do
      it 'returns nil for nil' do
        expect(format_rbs('nil')).to eq('nil')
      end

      it 'returns void for void' do
        expect(format_rbs('void')).to eq('void')
      end

      it 'returns Boolean for bool' do
        expect(format_rbs('bool')).to eq('Boolean')
      end

      it 'returns Boolean, nil for bool?' do
        expect(format_rbs('bool?')).to eq('Boolean, nil')
      end

      it 'returns untyped for untyped' do
        expect(format_rbs('untyped')).to eq('untyped')
      end

      it 'returns top for top' do
        expect(format_rbs('top')).to eq('top')
      end

      it 'returns bot for bot' do
        expect(format_rbs('bot')).to eq('bot')
      end

      it 'returns self for self' do
        expect(format_rbs('self')).to eq('self')
      end
    end

    context 'with class instances' do
      it 'returns Integer for Integer' do
        expect(format_rbs('Integer')).to eq('Integer')
      end

      it 'returns String for String' do
        expect(format_rbs('String')).to eq('String')
      end

      it 'returns Array for ::Array' do
        expect(format_rbs('::Array')).to eq('Array')
      end
    end

    context 'with optional types' do
      it 'returns String, nil for String?' do
        expect(format_rbs('String?')).to eq('String, nil')
      end

      it 'returns Integer, nil for Integer?' do
        expect(format_rbs('Integer?')).to eq('Integer, nil')
      end

      it 'returns Integer, String, nil for (Integer | String)?' do
        expect(format_rbs('(Integer | String)?')).to eq('Integer, String, nil')
      end
    end

    context 'with union types' do
      it 'returns Integer, String for Integer | String' do
        expect(format_rbs('Integer | String')).to eq('Integer, String')
      end

      it 'returns Integer, String, nil for Integer | String | nil' do
        expect(format_rbs('Integer | String | nil')).to eq('Integer, String, nil')
      end
    end

    context 'with intersection types' do
      it 'returns Comparable & Enumerable<Integer> for Comparable & Enumerable[Integer]' do
        expect(format_rbs('Comparable & Enumerable[Integer]'))
          .to eq('Comparable & Enumerable<Integer>')
      end
    end

    context 'with generic types' do
      it 'returns Array<String> for Array[String]' do
        expect(format_rbs('Array[String]')).to eq('Array<String>')
      end

      it 'returns Array<Integer, String> for Array[Integer | String]' do
        expect(format_rbs('Array[Integer | String]')).to eq('Array<Integer, String>')
      end

      it 'returns Array<Array<String>> for Array[Array[String]]' do
        expect(format_rbs('Array[Array[String]]')).to eq('Array<Array<String>>')
      end

      it 'returns Map<Symbol, Integer> for Map[Symbol, Integer]' do
        expect(format_rbs('Map[Symbol, Integer]')).to eq('Map<Symbol, Integer>')
      end
    end

    context 'with Hash types' do
      it 'returns Hash{Symbol => Integer} for Hash[Symbol, Integer]' do
        expect(format_rbs('Hash[Symbol, Integer]')).to eq('Hash{Symbol => Integer}')
      end

      it 'returns Hash{String => Array<Integer>} for Hash[String, Array[Integer]]' do
        expect(format_rbs('Hash[String, Array[Integer]]')).to eq('Hash{String => Array<Integer>}')
      end

      it 'returns Hash<Symbol> for Hash[Symbol]' do
        expect(format_rbs('Hash[Symbol]')).to eq('Hash<Symbol>')
      end
    end

    context 'with record types' do
      it 'returns Hash{Symbol => String} for { name: String }' do
        expect(format_rbs('{ name: String }')).to eq('Hash{Symbol => String}')
      end

      it 'returns Hash{Symbol => String, Integer} for { name: String, age: Integer }' do
        expect(format_rbs('{ name: String, age: Integer }'))
          .to eq('Hash{Symbol => String, Integer}')
      end

      it 'returns Hash{Symbol => String} for { name: String, nick: String }' do
        expect(format_rbs('{ name: String, nick: String }')).to eq('Hash{Symbol => String}')
      end

      it 'returns Hash{Symbol => String, Integer, nil} for { name: String, age: Integer? }' do
        expect(format_rbs('{ name: String, age: Integer? }'))
          .to eq('Hash{Symbol => String, Integer, nil}')
      end

      it 'returns Hash{Symbol => String, Integer} for { name: String, ?age: Integer }' do
        expect(format_rbs('{ name: String, ?age: Integer }'))
          .to eq('Hash{Symbol => String, Integer}')
      end

      it 'returns Hash{String, Integer => String, Integer} for a mixed record' do
        expect(format_rbs('{ "name" => String, 1 => Integer }'))
          .to eq('Hash{String, Integer => String, Integer}')
      end

      it 'returns Hash{String => String} for { "name" => String }' do
        expect(format_rbs('{ "name" => String }')).to eq('Hash{String => String}')
      end

      it 'returns Hash for { }' do
        expect(format_rbs('{ }')).to eq('Hash')
      end
    end

    context 'with tuple types' do
      it 'returns Array(Integer, String) for [Integer, String]' do
        expect(format_rbs('[Integer, String]')).to eq('Array(Integer, String)')
      end

      it 'returns Array(Integer, (String, nil)) for [Integer, String?]' do
        expect(format_rbs('[Integer, String?]')).to eq('Array(Integer, (String, nil))')
      end

      it 'returns Array(Integer) for [Integer]' do
        expect(format_rbs('[Integer]')).to eq('Array(Integer)')
      end

      it 'returns Array((Integer, nil), String) for [Integer?, String]' do
        expect(format_rbs('[Integer?, String]')).to eq('Array((Integer, nil), String)')
      end

      it 'returns Array((Integer, Symbol)) for [Integer | Symbol]' do
        expect(format_rbs('[Integer | Symbol]')).to eq('Array((Integer, Symbol))')
      end

      it 'returns Array for []' do
        expect(format_rbs('[]')).to eq('Array')
      end
    end

    context 'with proc types' do
      it 'returns Proc for ^(Integer) -> String' do
        expect(format_rbs('^(Integer) -> String')).to eq('Proc')
      end
    end

    context 'with literal types' do
      it 'returns 1 for 1' do
        expect(format_rbs('1')).to eq('1')
      end

      it 'returns "hello" for "hello"' do
        expect(format_rbs('"hello"')).to eq('"hello"')
      end

      it 'returns :ok for :ok' do
        expect(format_rbs(':ok')).to eq(':ok')
      end
    end

    context 'with type variables' do
      it 'returns the name of the variable' do
        method_type = parse_method_type('[T] (T) -> T')
        param_type = method_type.type.required_positionals.first.type
        expect(described_class.format(param_type)).to eq('T')
      end
    end
  end
end
