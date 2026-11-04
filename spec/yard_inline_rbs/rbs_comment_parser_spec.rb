# frozen_string_literal: true

RSpec.describe YardInlineRbs::RbsCommentParser do
  def parse(rbs_tag_texts: [], inline_annotations: [], source_line: '')
    described_class.new(rbs_tag_texts, inline_annotations, source_line).parse
  end

  def no_annotations
    have_attributes(return_type: nil, positional_param_types: [], named_param_types: {},
                    block_annotation: nil)
  end

  describe '#parse' do
    context 'with overloads in an @rbs signature' do
      subject(:result) do
        parse(rbs_tag_texts: ["(Integer count) -> String\n  | (Float count) -> Float"])
      end

      it 'collects a signature for each overload' do
        expect(result.overloads.map {|signature| signature[:return_type]})
          .to eq(%w[String Float])
      end

      it 'records no parameters, parse errors or duplicates' do
        expect([result.positional_param_types, result.parse_errors, result.duplicate_annotations])
          .to eq([[], [], []])
      end
    end

    context 'with overloads of which one cannot be parsed' do
      subject(:result) do
        parse(rbs_tag_texts: ["(Integer count) -> String\n  | (Float count -> Float"])
      end

      it 'uses the one that can be parsed as the signature' do
        expect([result.return_type, result.overloads]).to eq(['String', []])
      end

      it 'records the other as a parse error' do
        expect(result.parse_errors).to eq(['(Float count -> Float'])
      end
    end

    context 'with overloads and a second signature' do
      subject(:result) do
        parse(rbs_tag_texts: ["(Integer) -> String\n  | (Float) -> Float", '(Symbol) -> Symbol'])
      end

      it 'keeps the overloads and records the duplicate' do
        expect([result.overloads.size, result.duplicate_annotations]).to eq([2, ['the signature']])
      end
    end

    context 'with a block annotation that has an optional parameter' do
      subject(:result) {parse(rbs_tag_texts: ['&block: (Integer, ?String) -> void'])}

      it 'documents every parameter the block can receive' do
        expect(result.block_annotation).to have_attributes(yield_types: %w[Integer String])
      end
    end

    context 'with a tuple that contains a proc type' do
      subject(:result) {parse(rbs_tag_texts: ['[^() -> void, Integer]'])}

      it 'types the return value, without a parse error' do
        expect([result.return_type, result.parse_errors]).to eq(['Array(Proc, Integer)', []])
      end
    end

    context 'with a parenthesised proc type' do
      subject(:result) {parse(rbs_tag_texts: ['(^(Integer) -> String)'])}

      it 'types the return value, without a parse error' do
        expect([result.return_type, result.parse_errors]).to eq(['Proc', []])
      end
    end

    context 'with override, generic, inherits and use annotations' do
      subject(:result) do
        parse(rbs_tag_texts: ['override', 'generic T', 'inherits Foo', 'use Foo::Bar'])
      end

      it 'finds no annotations and reports no problems' do
        expect([result, result.parse_errors, result.unsupported_annotations])
          .to match([no_annotations, [], []])
      end
    end

    context 'with an invalid block annotation after a valid block type' do
      subject(:result) do
        parse(rbs_tag_texts: ['(Integer) { (String) -> void } -> void', '&blk: nope['])
      end

      it 'keeps the valid block and records the error' do
        expect([result.block_annotation.yield_types, result.parse_errors])
          .to eq([['String'], ['nope[']])
      end
    end

    context 'with a proc type in a named annotation' do
      subject(:result) {parse(rbs_tag_texts: ['callback: ^(Integer) -> void'])}

      it 'types the parameter as a Proc, without a parse error' do
        expect([result.named_param_types['callback'].type, result.parse_errors])
          .to eq(['Proc', []])
      end
    end

    context 'with a proc type in a return annotation' do
      subject(:result) {parse(rbs_tag_texts: ['return: ^() -> String'])}

      it 'types the return value as a Proc, without a parse error' do
        expect([result.return_type, result.parse_errors]).to eq(['Proc', []])
      end
    end

    context 'with a generic type that contains a proc type' do
      subject(:result) {parse(rbs_tag_texts: ['Hash[Symbol, ^() -> void]'])}

      it 'types the return value, without a parse error' do
        expect([result.return_type, result.parse_errors]).to eq(['Hash{Symbol => Proc}', []])
      end
    end

    context 'with a namespaced type without a name' do
      subject(:result) {parse(rbs_tag_texts: ['Foo::Bar'])}

      it 'types the return value, not a parameter named Foo' do
        expect([result.return_type, result.named_param_types]).to eq(['Foo::Bar', {}])
      end
    end

    context 'with a splat annotation without a type' do
      it 'records a parse error' do
        expect(parse(rbs_tag_texts: ['*names:']).parse_errors).to eq(['*names:'])
      end
    end

    context 'with an empty @rbs tag' do
      it 'records an empty parse error' do
        expect(parse(rbs_tag_texts: ['']).parse_errors).to eq([''])
      end
    end

    context 'with a plain type in the @rbs tag' do
      it 'sets the return type' do
        expect(parse(rbs_tag_texts: ['Integer']).return_type).to eq('Integer')
      end
    end

    context 'with a block annotation without a type' do
      it 'records a parse error' do
        expect(parse(rbs_tag_texts: ['&block']).parse_errors).to eq(['&block'])
      end
    end

    context 'with a description line that looks like a named annotation' do
      subject(:result) {parse(rbs_tag_texts: ["Integer -- the count\nNote: a big one"])}

      it 'types the return value, without a parameter' do
        expect([result.return_type, result.return_description, result.named_param_types])
          .to eq(['Integer', nil, {}])
      end
    end

    context 'with a description line that looks like a splat annotation' do
      subject(:result) {parse(rbs_tag_texts: ["Integer -- the count\n*args: more"])}

      it 'types the return value, without a parameter' do
        expect([result.return_type, result.named_param_types, result.parse_errors])
          .to eq(['Integer', {}, []])
      end
    end

    context 'with a block annotation that continues with a line that looks like another' do
      subject(:result) {parse(rbs_tag_texts: ["&nonsense\n&block: Proc"])}

      it 'records a parse error, and no block' do
        expect([result.block_annotation,
                result.parse_errors]).to eq([nil, ["&nonsense\n&block: Proc"]])
      end
    end

    context 'with an instance variable annotation over several lines' do
      subject(:result) {parse(rbs_tag_texts: ["@items: Array[\n  Integer]"])}

      it 'records it as unsupported, without a parse error' do
        expect([result.unsupported_annotations, result.parse_errors])
          .to eq([["@items: Array[\n  Integer]"], []])
      end
    end

    context 'with a class variable annotation' do
      subject(:result) {parse(rbs_tag_texts: ['@@count: Integer'])}

      it 'records it as unsupported, without a parse error' do
        expect([result.unsupported_annotations, result.parse_errors])
          .to eq([['@@count: Integer'], []])
      end
    end

    context 'with an instance variable annotation without a type' do
      it 'ignores the annotation' do
        expect(parse(rbs_tag_texts: ['@count']).unsupported_annotations).to eq([])
      end
    end

    context 'with an invalid method signature' do
      it 'records a parse error' do
        expect(parse(rbs_tag_texts: ['(Integer -> bool']).parse_errors).to eq(['(Integer -> bool'])
      end
    end

    context 'with a full method signature in @rbs tag' do
      subject(:result) {parse(rbs_tag_texts: ['(Integer, String) -> bool'])}

      it 'extracts positional param types' do
        expect(result.positional_param_types.map(&:type)).to eq(%w[Integer String])
      end

      it 'extracts the return type' do
        expect(result.return_type).to eq('Boolean')
      end
    end

    context 'with named params in the signature' do
      subject(:result) {parse(rbs_tag_texts: ['(Integer x, String y) -> bool'])}

      it 'sets names from the signature' do
        expect(result.positional_param_types.map(&:name)).to eq(%w[x y])
      end
    end

    context 'with individual @rbs param annotations' do
      subject(:result) do
        parse(rbs_tag_texts: ['name: String', 'count: Integer'])
      end

      it 'extracts named param types' do
        expect(result.named_param_types.transform_values(&:type))
          .to eq('name' => 'String', 'count' => 'Integer')
      end

      it 'has no description when -- is absent' do
        expect(result.named_param_types['name'].description).to be_nil
      end
    end

    context 'with @rbs return annotation' do
      subject(:result) {parse(rbs_tag_texts: ['return: String'])}

      it 'extracts the return type' do
        expect(result.return_type).to eq('String')
      end
    end

    context 'with @rbs ivar annotation' do
      subject(:result) {parse(rbs_tag_texts: ['@name: String'])}

      it 'records an unsupported annotation warning' do
        expect(result.unsupported_annotations).to include('@name: String')
      end
    end

    context 'with @rbs ivar annotation with a description' do
      subject(:result) {parse(rbs_tag_texts: ['@name: String -- The name.'])}

      it 'records no parse error' do
        expect(result.parse_errors).to eq([])
      end
    end

    context 'with @rbs ivar annotation with an invalid type' do
      subject(:result) {parse(rbs_tag_texts: ['@name: Array['])}

      it 'records a parse error, although the annotation is not used' do
        expect(result.parse_errors).to eq(['Array['])
      end
    end

    context 'with a description on a block, a plain type and a method signature' do
      subject(:result) do
        parse(rbs_tag_texts: ['&block: (Integer) -> void -- The callback.',
                              'String -- The name.'])
      end

      it 'types them, without a parse error' do
        expect([result.block_annotation.yield_types, result.return_type, result.parse_errors])
          .to eq([['Integer'], 'String', []])
      end
    end

    context 'with a description on a tuple' do
      subject(:result) {parse(rbs_tag_texts: ['[Integer, String] -- The pair.'])}

      it 'types the return value, without a parse error' do
        expect([result.return_type, result.parse_errors])
          .to eq(['Array(Integer, String)', []])
      end
    end

    context 'with a description on a record that contains a proc type' do
      subject(:result) {parse(rbs_tag_texts: ['{ call: ^() -> void } -- The handlers.'])}

      it 'types the return value, without a parse error' do
        expect([result.return_type, result.parse_errors]).to eq(['Hash{Symbol => Proc}', []])
      end
    end

    context 'with a description on a method signature' do
      subject(:result) {parse(rbs_tag_texts: ['(Integer) -> String -- The label.'])}

      it 'types it, without a parse error' do
        expect([result.return_type, result.parse_errors]).to eq(['String', []])
      end
    end

    # Which annotation wins is a choice: the first one, like @rbs over #:.
    context 'with two annotations of the same parameter or return value' do
      subject(:result) do
        parse(rbs_tag_texts: ['return: Integer -- The first.', 'return: Float -- The second.',
                              'count: Integer', 'count: Float',
                              '*rest: Integer', '*rest: Float'])
      end

      it 'uses the first' do
        expect([result.return_type, result.return_description,
                result.named_param_types.transform_values(&:type)])
          .to eq(['Integer', 'The first.', { 'count' => 'Integer', 'rest' => 'Integer' }])
      end
    end

    context 'with a return annotation before a plain type and a method signature' do
      subject(:result) {parse(rbs_tag_texts: ['return: Integer', 'String', '(Float) -> Float'])}

      it 'uses the return annotation' do
        expect(result.return_type).to eq('Integer')
      end
    end

    context 'with a block annotation before a method signature with a block' do
      subject(:result) do
        parse(rbs_tag_texts: ['&block: (Integer) -> void', '() { (String) -> void } -> void'])
      end

      it 'uses the block annotation' do
        expect(result.block_annotation.yield_types).to eq(['Integer'])
      end
    end

    context 'with an optional type' do
      subject(:result) {parse(rbs_tag_texts: ['(String?) -> void'])}

      it 'formats the optional type' do
        expect(result.positional_param_types.first.type).to eq('String, nil')
      end
    end

    context 'with inline #: type line' do
      subject(:result) {parse(inline_annotations: [': (Integer) -> String'])}

      it 'extracts positional param types' do
        expect(result.positional_param_types.first.type).to eq('Integer')
      end

      it 'extracts the return type' do
        expect(result.return_type).to eq('String')
      end
    end

    context 'with a standalone inline #: type (for attr/const)' do
      subject(:result) {parse(inline_annotations: [': String'])}

      it 'extracts the type as return_type' do
        expect(result.return_type).to eq('String')
      end
    end

    context 'with a trailing #: annotation on the source line' do
      subject(:result) {parse(source_line: 'def foo(x) #: String')}

      it 'extracts the return type' do
        expect(result.return_type).to eq('String')
      end
    end

    context 'with a trailing #: full method type on source line' do
      subject(:result) {parse(source_line: 'def foo(x) #: (Integer) -> String')}

      it 'extracts the return type' do
        expect(result.return_type).to eq('String')
      end
    end

    context 'with @rbs taking precedence over inline #:' do
      subject(:result) do
        parse(rbs_tag_texts: ['return: Integer'], inline_annotations: [': String'])
      end

      it 'uses the @rbs return type' do
        expect(result.return_type).to eq('Integer')
      end
    end

    context 'with a -- description suffix on a named param annotation' do
      subject(:result) do
        parse(rbs_tag_texts: ['argument_expressions: Array[String] -- Ordered list of nodes'])
      end

      it 'extracts the param type, ignoring the description' do
        expect(result.named_param_types['argument_expressions'].type).to eq('Array<String>')
      end

      it 'captures the description from after --' do
        expect(result.named_param_types['argument_expressions'].description)
          .to eq('Ordered list of nodes')
      end
    end

    context 'with a multi-line -- description (continuation indented line)' do
      subject(:result) do
        parse(rbs_tag_texts: ["argument_expressions: Array[String] -- First line\ncontinuation"])
      end

      it 'extracts the type correctly' do
        expect(result.named_param_types['argument_expressions'].type).to eq('Array<String>')
      end

      it 'joins the continuation line into the description' do
        expect(result.named_param_types['argument_expressions'].description)
          .to eq('First line continuation')
      end
    end

    context 'with a -- description on a return annotation' do
      subject(:result) {parse(rbs_tag_texts: ['return: String -- the result'])}

      it 'extracts the return type' do
        expect(result.return_type).to eq('String')
      end

      it 'captures the return description' do
        expect(result.return_description).to eq('the result')
      end
    end

    context 'with a -- description on a continuation line of a return annotation' do
      subject(:result) do
        parse(rbs_tag_texts: ["return: String | Integer\n-- The combined result."])
      end

      it 'extracts the return type' do
        expect(result.return_type).to eq('String, Integer')
      end

      it 'captures the description from the continuation line' do
        expect(result.return_description).to eq('The combined result.')
      end
    end

    context 'with a -- description suffix on an inline #: type line' do
      subject(:result) {parse(inline_annotations: [': String -- A helpful description.'])}

      it 'extracts the type, ignoring the description' do
        expect(result.return_type).to eq('String')
      end

      it 'records no parse errors' do
        expect(result.parse_errors).to be_empty
      end
    end

    context 'with a -- description suffix on a trailing #: annotation' do
      subject(:result) do
        parse(source_line: "MY_CONST = 'value' #: String -- A helpful description.")
      end

      it 'extracts the type, ignoring the description' do
        expect(result.return_type).to eq('String')
      end

      it 'records no parse errors' do
        expect(result.parse_errors).to be_empty
      end
    end

    context 'with a splat rest param annotation (*name: Type)' do
      subject(:result) {parse(rbs_tag_texts: ['*names: String'])}

      it 'records no parse errors' do
        expect(result.parse_errors).to be_empty
      end

      it 'injects a named param with the element type' do
        expect(result.named_param_types['names'].type).to eq('String')
      end
    end

    context 'with a double-splat keyword-rest param annotation (**name: Type)' do
      subject(:result) {parse(rbs_tag_texts: ['**options: untyped'])}

      it 'records no parse errors' do
        expect(result.parse_errors).to be_empty
      end

      it 'injects a named param with the value type' do
        expect(result.named_param_types['options'].type).to eq('untyped')
      end
    end

    context 'with a named block annotation (&block: (Type) -> ReturnType)' do
      subject(:result) {parse(rbs_tag_texts: ['&block: (String) -> void'])}

      it 'captures the yield types' do
        expect(result.block_annotation.yield_types).to eq(['String'])
      end

      it 'captures the yield return type' do
        expect(result.block_annotation.return_type).to eq('void')
      end

      it 'records no parse errors' do
        expect(result.parse_errors).to be_empty
      end
    end

    context 'with an anonymous block annotation with no params (&: () -> void)' do
      subject(:result) {parse(rbs_tag_texts: ['&: () -> void'])}

      it 'has empty yield types' do
        expect(result.block_annotation.yield_types).to be_empty
      end

      it 'captures the yield return type' do
        expect(result.block_annotation.return_type).to eq('void')
      end

      it 'records no parse errors' do
        expect(result.parse_errors).to be_empty
      end
    end

    context 'with a block annotation with rest params (&: (*untyped) -> untyped)' do
      subject(:result) {parse(rbs_tag_texts: ['&: (*untyped) -> untyped'])}

      it 'captures the rest type as yield type' do
        expect(result.block_annotation.yield_types).to eq(['untyped'])
      end

      it 'captures the yield return type' do
        expect(result.block_annotation.return_type).to eq('untyped')
      end
    end

    context 'with a valid-type but non-method-type block annotation (&block: Proc)' do
      subject(:result) {parse(rbs_tag_texts: ['&block: Proc'])}

      it 'records no parse error' do
        expect(result.parse_errors).to be_empty
      end

      it 'records no unsupported annotation warning' do
        expect(result.unsupported_annotations).to be_empty
      end

      it 'has a block annotation with no yield types' do
        expect(result.block_annotation.yield_types).to be_empty
      end

      it 'has no yield return type' do
        expect(result.block_annotation.return_type).to be_nil
      end
    end

    context 'with a truly unparseable block type annotation (&block: !!!)' do
      subject(:result) {parse(rbs_tag_texts: ['&block: !!!'])}

      it 'records a parse error' do
        expect(result.parse_errors).to include('!!!')
      end

      it 'has no block annotation' do
        expect(result.block_annotation).to be_nil
      end
    end

    context 'with an RBS def declaration (@rbs def method: ...)' do
      subject(:result) {parse(rbs_tag_texts: ['def my_method: (String) -> Integer'])}

      it 'records no parse errors' do
        expect(result.parse_errors).to be_empty
      end

      it 'records an unsupported annotation warning' do
        expect(result.unsupported_annotations).to include('def my_method: (String) -> Integer')
      end
    end

    context 'with RBS structural annotations (@rbs class ... @rbs end)' do
      subject(:result) do
        parse(rbs_tag_texts: ['class PendingStep', 'attr_reader step: untyped',
                              'attr_writer size: Integer', 'attr_accessor name: String', 'end'])
      end

      it 'records no parse errors' do
        expect(result.parse_errors).to be_empty
      end

      it 'records unsupported annotation warnings for each' do
        expect(result.unsupported_annotations)
          .to eq(['class PendingStep', 'attr_reader step: untyped', 'attr_writer size: Integer',
                  'attr_accessor name: String', 'end'])
      end
    end

    context 'with a -- separator at the end of the line and the description below it' do
      subject(:result) do
        parse(rbs_tag_texts: ["x: Integer --\nthe first operand,\non two lines"])
      end

      it 'extracts the type and joins the description lines' do
        expect(result.named_param_types['x'])
          .to have_attributes(type: 'Integer', description: 'the first operand, on two lines')
      end

      it 'records no parse errors' do
        expect(result.parse_errors).to be_empty
      end
    end

    context 'with a signature containing optional, rest and keyword params' do
      subject(:result) do
        parse(rbs_tag_texts: [
                '(Integer x, ?Integer y, *String rest, name: String, ?flag: bool, '\
                '**Integer opts) -> void'
              ])
      end

      it 'extracts required, optional and rest positionals in order' do
        expect(result.positional_param_types.map {|param| [param.name, param.type]})
          .to eq([%w[x Integer], %w[y Integer], %w[rest String]])
      end

      it 'extracts required, optional and rest keywords' do
        expect(result.named_param_types.transform_values(&:type))
          .to eq({ 'name' => 'String', 'flag' => 'Boolean', 'opts' => 'Integer' })
      end
    end

    context 'with an unnamed keyword rest in the signature' do
      subject(:result) {parse(rbs_tag_texts: ['(**bool) -> void'])}

      it 'records the keyword rest under the ** placeholder name' do
        expect(result.named_param_types.transform_values(&:type)).to eq({ '**' => 'Boolean' })
      end
    end

    context 'with a block in the method signature' do
      subject(:result) do
        parse(rbs_tag_texts: ['(Integer count) { (String, Integer) -> bool } -> void'])
      end

      it 'captures the block as a block annotation' do
        expect(result.block_annotation)
          .to have_attributes(yield_types: %w[String Integer], return_type: 'Boolean')
      end
    end

    context 'with a block in an inline #: method signature' do
      subject(:result) {parse(inline_annotations: [': () { () -> void } -> Proc'])}

      it 'captures the block as a block annotation' do
        expect(result.block_annotation).to have_attributes(yield_types: [], return_type: 'void')
      end
    end

    context 'with an optional block annotation (&block: ? () -> untyped)' do
      subject(:result) {parse(rbs_tag_texts: ['&block: ? (String) -> untyped'])}

      it 'captures the block type' do
        expect(result.block_annotation)
          .to have_attributes(yield_types: ['String'], return_type: 'untyped')
      end

      it 'records no parse errors' do
        expect(result.parse_errors).to be_empty
      end
    end

    context 'with unnamed splat annotations (*: Type, **: Type)' do
      subject(:result) {parse(rbs_tag_texts: ['*: String -- the names', '**: bool'])}

      it 'records them under the * and ** placeholder names' do
        expect(result.named_param_types)
          .to match('*' => have_attributes(type: 'String', description: 'the names'),
                    '**' => have_attributes(type: 'Boolean', description: nil))
      end

      it 'records no parse errors' do
        expect(result.parse_errors).to be_empty
      end
    end

    context 'with annotations that have no documentation meaning' do
      subject(:result) do
        parse(rbs_tag_texts: ['skip', '...', 'module-self: Comparable -- for sorting'])
      end

      it 'returns an empty result' do
        expect(result).to no_annotations
      end

      it 'records no parse errors or unsupported annotations' do
        expect([result.parse_errors, result.unsupported_annotations]).to eq([[], []])
      end
    end

    context 'with a proc type on an inline #: line' do
      subject(:result) {parse(inline_annotations: [': ^(Integer) -> String'])}

      it 'extracts the proc type as return type' do
        expect(result.return_type).to eq('Proc')
      end

      it 'records no parse errors' do
        expect(result.parse_errors).to be_empty
      end
    end

    context 'with a proc type in a trailing #: annotation' do
      subject(:result) {parse(source_line: 'CALLBACK = -> {} #: ^() -> void')}

      it 'extracts the proc type as return type' do
        expect(result.return_type).to eq('Proc')
      end

      it 'records no parse errors' do
        expect(result.parse_errors).to be_empty
      end
    end

    context 'with a class-alias or module-alias annotation' do
      subject(:result) do
        parse(inline_annotations: [': class-alias'],
              source_line: 'MyKernel = kernel #: module-alias Kernel')
      end

      it 'returns an empty result' do
        expect(result).to no_annotations
      end

      it 'records no parse errors' do
        expect(result.parse_errors).to be_empty
      end
    end

    context 'with an invalid RBS type string' do
      subject(:result) {parse(rbs_tag_texts: ['return: !!!invalid!!!!'])}

      it 'returns nil for unparseable types' do
        expect(result.return_type).to be_nil
      end
    end

    context 'with no annotations' do
      subject(:result) {parse}

      it 'returns an empty result' do
        expect(result).to no_annotations
      end
    end
  end

  describe '#initialize' do
    it 'does not parse the annotations until #parse is called' do
      expect(RBS::Parser).not_to receive(:parse_type)
      described_class.new(['String'], [], '')
    end
  end
end
