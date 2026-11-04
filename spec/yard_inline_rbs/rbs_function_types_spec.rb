# frozen_string_literal: true

RSpec.describe YardInlineRbs::RbsFunctionTypes do
  def function_types(method_type)
    described_class.new(RBS::Parser.parse_method_type(method_type).type)
  end

  describe '#positional_types' do
    context 'with required, optional, rest and trailing positionals' do
      subject(:types) {function_types('(Integer x, ?String, *Symbol rest, bool last) -> void')}

      it 'returns them in Ruby order with their names, if any' do
        expect(types.positional_types)
          .to match([have_attributes(type: 'Integer', name: 'x'),
                     have_attributes(type: 'String', name: nil),
                     have_attributes(type: 'Symbol', name: 'rest'),
                     have_attributes(type: 'Boolean', name: 'last')])
      end
    end

    context 'without params' do
      it 'returns an empty list' do
        expect(function_types('() -> void').positional_types).to eq([])
      end
    end
  end

  describe '#named_types' do
    context 'with required, optional and rest keywords' do
      subject(:types) {function_types('(name: String, ?flag: bool, **Integer opts) -> void')}

      it 'returns them by name, without description' do
        expect(types.named_types)
          .to match('name' => have_attributes(type: 'String', description: nil),
                    'flag' => have_attributes(type: 'Boolean', description: nil),
                    'opts' => have_attributes(type: 'Integer', description: nil))
      end
    end

    context 'with a named keyword rest next to keywords' do
      it 'marks only the keyword rest' do
        types = function_types('(name: String, **Integer opts) -> void')
        expect(types.named_types)
          .to match('name' => have_attributes(rest: false), 'opts' => have_attributes(rest: true))
      end
    end

    context 'with an unnamed keyword rest' do
      it 'returns it under the ** placeholder name' do
        expect(function_types('(**bool) -> void').named_types.transform_values(&:type))
          .to eq({ '**' => 'Boolean' })
      end
    end
  end

  describe '#yield_types' do
    context 'with required and rest positionals' do
      it 'returns their types' do
        expect(function_types('(String, *Integer) -> void').yield_types)
          .to eq(%w[String Integer])
      end
    end

    context 'with optional positionals' do
      it 'includes them' do
        expect(function_types('(String, ?Integer) -> void').yield_types).to eq(%w[String Integer])
      end
    end

    context 'with a positional after the rest positional' do
      it 'includes it' do
        expect(function_types('(String, *Integer, Symbol) -> void').yield_types)
          .to eq(%w[String Integer Symbol])
      end
    end

    context 'with every kind of positional' do
      it 'returns them in Ruby order' do
        expect(function_types('(String, ?Integer, *Symbol, Float) -> void').yield_types)
          .to eq(%w[String Integer Symbol Float])
      end
    end

    context 'with named positionals' do
      it 'returns their types without the names' do
        expect(function_types('(String item, ?Integer index) -> void').yield_types)
          .to eq(%w[String Integer])
      end
    end
  end

  describe '#return_type' do
    it 'returns the YARD return type' do
      expect(function_types('() -> Array[String]?').return_type).to eq('Array<String>, nil')
    end
  end

  describe '#initialize' do
    it 'reads the types from the given function type' do
      expect(function_types('(Integer x) -> String').return_type).to eq('String')
    end
  end
end
