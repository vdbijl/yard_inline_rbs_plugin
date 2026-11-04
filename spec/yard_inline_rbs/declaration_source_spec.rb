# frozen_string_literal: true

require 'tempfile'
require 'tmpdir'

RSpec.describe YardInlineRbs::DeclarationSource do
  def method_object(source: '', files: [])
    instance_double(YARD::CodeObjects::MethodObject, source: source, files: files)
  end

  def handler(file:, line:, comments_range: nil)
    statement = instance_double(YARD::Parser::Ruby::AstNode, line: line,
                                                             comments_range: comments_range)
    instance_double(YARD::Handlers::Ruby::MethodHandler,
                    parser: instance_double(YARD::Handlers::Processor, file: file),
                    statement: statement)
  end

  describe '#initialize' do
    it 'does not read the source yet' do
      object = instance_double(YARD::CodeObjects::MethodObject)
      expect {described_class.new(object)}.not_to raise_error
    end
  end

  describe '#location' do
    context 'with the handler that parses the docstring' do
      it 'returns the file and the line of the statement of the handler' do
        object = method_object(files: [['sig/shop.rbs', 3], ['lib/shop.rb', 7]])
        source = described_class.new(object, handler(file: 'lib/shop.rb', line: 7))
        expect(source.location).to eq(['lib/shop.rb', 7])
      end
    end

    # YARD lists the first declaration with a comment first, which is the .rbs file when it has
    # a comment, because the plugin parses the .rbs files first.
    context 'without a handler, for an object declared in a .rbs file and a Ruby file' do
      it 'returns the Ruby declaration' do
        object = method_object(files: [['sig/shop.rbs', 3], ['lib/shop.rb', 7]])
        expect(described_class.new(object).location).to eq(['lib/shop.rb', 7])
      end
    end

    context 'without a handler, for an object declared only in a .rbs file' do
      it 'returns the .rbs declaration' do
        object = method_object(files: [['sig/shop.rbs', 3]])
        expect(described_class.new(object).location).to eq(['sig/shop.rbs', 3])
      end
    end

    context 'without a handler, for an object declared in two .rbs files' do
      it 'returns the first .rbs declaration' do
        object = method_object(files: [['sig/shop.rbs', 3], ['sig/shop_extra.rbs', 9]])
        expect(described_class.new(object).location).to eq(['sig/shop.rbs', 3])
      end
    end

    context 'without a handler and without files' do
      it 'returns nil' do
        expect(described_class.new(method_object).location).to be_nil
      end
    end
  end

  describe '#location_text' do
    it 'returns the file and line separated by a colon' do
      object = method_object(files: [['lib/shop.rb', 7]])
      expect(described_class.new(object).location_text).to eq('lib/shop.rb:7')
    end

    context 'with a file without a line number' do
      it 'returns the file' do
        object = method_object(files: [['lib/shop.rb', nil]])
        expect(described_class.new(object).location_text).to eq('lib/shop.rb')
      end
    end

    context 'without a location' do
      it 'returns an empty string' do
        expect(described_class.new(method_object).location_text).to eq('')
      end
    end
  end

  describe '#first_line' do
    context 'when the object has no file, such as when YARD parses a string' do
      it 'returns the first line of the source of the object' do
        object = method_object(source: "def foo\n  1\nend")
        expect(described_class.new(object).first_line).to eq("def foo\n")
      end
    end

    context 'when the declaration is in a file' do
      let(:source_file) {Tempfile.new(['widget', '.rb'])}

      before do
        source_file.write("class Widget\n  attr_accessor :count #: Integer\nend\n")
        source_file.flush
      end

      after {source_file.close!}

      it 'returns the original line of the file' do
        object = method_object(source: 'def count=(value)', files: [[source_file.path, 2]])
        expect(described_class.new(object).first_line).to eq("  attr_accessor :count #: Integer\n")
      end

      it 'returns the line of the handler statement when YARD lists another file first' do
        object = method_object(source: 'def count', files: [['sig/widget.rbs', 1]])
        source = described_class.new(object, handler(file: source_file.path, line: 2))
        expect(source.first_line).to eq("  attr_accessor :count #: Integer\n")
      end

      it 'returns the first line of the source of the object when the file has no line number' do
        object = method_object(source: 'def count=(value)', files: [[source_file.path, nil]])
        expect(described_class.new(object).first_line).to eq('def count=(value)')
      end

      it 'returns the first line of the source of the object when the line is past the file' do
        object = method_object(source: 'def count=(value)', files: [[source_file.path, 9]])
        expect(described_class.new(object).first_line).to eq('def count=(value)')
      end
    end

    context 'when the file cannot be read' do
      it 'returns the first line of the source of the object' do
        object = method_object(source: 'def count=(value)', files: [['gone/widget.rb', 2]])
        expect(described_class.new(object).first_line).to eq('def count=(value)')
      end
    end

    context 'when the file is (stdin), as with YARD.parse_string' do
      around do |example|
        Dir.mktmpdir do |directory|
          File.write(File.join(directory, '(stdin)'), "class Widget\n")
          Dir.chdir(directory) {example.run}
        end
      end

      it 'returns the first line of the source, even if a file named (stdin) exists' do
        object = method_object(source: 'def count', files: [['(stdin)', 1]])
        expect(described_class.new(object).first_line).to eq('def count')
      end
    end

    context 'when several objects are declared in the same file' do
      let(:source_file) {Tempfile.new(['shop', '.rb'])}
      let(:objects) do
        [method_object(source: 'def a', files: [[source_file.path, 2]]),
         method_object(source: 'def b', files: [[source_file.path, 3]])]
      end

      before do
        source_file.write("class Shop\n  attr_reader :a #: Integer\n  attr_reader :b #: String\n")
        source_file.flush
        described_class.clear_cache
      end

      after {source_file.close!}

      it 'reads the file once' do
        expect(File).to receive(:readlines).with(source_file.path).once.and_call_original
        objects.each {|object| described_class.new(object).first_line}
      end
    end
  end

  describe '#comment_of_earlier_statement?' do
    let(:source_file) {Tempfile.new(['api', '.rb'])}

    before do
      source_file.write("  ONE = 'a' #: String\n  # Two.\n  TWO = 'b'\n")
      source_file.flush
    end

    after {source_file.close!}

    def source_with(comments_range, file: source_file.path)
      described_class.new(method_object,
                          handler(file: file, line: 3, comments_range: comments_range))
    end

    context 'when the comment is the trailing comment of an earlier line' do
      it 'returns true' do
        expect(source_with(1..1).comment_of_earlier_statement?).to be(true)
      end
    end

    context 'when the comments start on an earlier line and run up to the declaration line' do
      it 'returns true when the first comment line is not a comment line' do
        expect(source_with(1..3).comment_of_earlier_statement?).to be(true)
      end

      it 'returns false when the first comment line is a comment line' do
        expect(source_with(2..3).comment_of_earlier_statement?).to be(false)
      end
    end

    context 'when the comment is a comment line above the declaration' do
      it 'returns false' do
        expect(source_with(2..2).comment_of_earlier_statement?).to be(false)
      end
    end

    context 'when the statement has no line' do
      it 'returns false' do
        source = described_class.new(method_object,
                                     handler(file: source_file.path, line: nil,
                                             comments_range: 1..1))
        expect(source.comment_of_earlier_statement?).to be(false)
      end
    end

    context 'when the comment is on the declaration line' do
      it 'returns false' do
        expect(source_with(3..3).comment_of_earlier_statement?).to be(false)
      end
    end

    context 'when the file cannot be read' do
      it 'returns false' do
        expect(source_with(1..1, file: 'gone/api.rb').comment_of_earlier_statement?).to be(false)
      end
    end

    context 'without a comment' do
      it 'returns false' do
        expect(source_with(nil).comment_of_earlier_statement?).to be(false)
      end
    end

    context 'without a handler' do
      it 'returns false' do
        expect(described_class.new(method_object).comment_of_earlier_statement?).to be(false)
      end
    end
  end

  describe '#trailing_comment_line' do
    let(:declaration) {method_object(source: 'def count #: Integer')}

    context 'when the comment is a trailing comment on the declaration line' do
      it 'returns nil, because the comment is the docstring' do
        source = described_class.new(declaration, handler(file: 'gone/shop.rb', line: 7,
                                                          comments_range: 7..7))
        expect(source.trailing_comment_line).to be_nil
      end
    end

    context 'when the comment is above the declaration' do
      it 'returns the first line' do
        source = described_class.new(declaration, handler(file: 'gone/shop.rb', line: 7,
                                                          comments_range: 5..6))
        expect(source.trailing_comment_line).to eq('def count #: Integer')
      end
    end

    context 'without a comment' do
      it 'returns the first line' do
        source = described_class.new(declaration, handler(file: 'gone/shop.rb', line: 7))
        expect(source.trailing_comment_line).to eq('def count #: Integer')
      end
    end

    context 'without a handler' do
      it 'returns the first line' do
        expect(described_class.new(declaration).trailing_comment_line)
          .to eq('def count #: Integer')
      end
    end
  end

  describe '#superclass_type_application' do
    context 'with a type application on a generic superclass' do
      it 'returns the type application' do
        object = method_object(source: 'class StringArray < Array #[String]')
        expect(described_class.new(object).superclass_type_application).to eq('[String]')
      end
    end

    context 'with a class without type application' do
      it 'returns nil' do
        object = method_object(source: 'class StringArray < Array')
        expect(described_class.new(object).superclass_type_application).to be_nil
      end
    end
  end

  describe '.lines_of' do
    let(:source_file) {Tempfile.new(['widget', '.rb'])}

    before do
      source_file.write("class Widget\nend\n")
      source_file.flush
      described_class.clear_cache
    end

    after {source_file.close!}

    it 'returns the lines of the file' do
      expect(described_class.lines_of(source_file.path)).to eq(["class Widget\n", "end\n"])
    end
  end

  describe '.clear_cache' do
    let(:source_file) {Tempfile.new(['widget', '.rb'])}
    let(:object) {method_object(source: 'def count', files: [[source_file.path, 1]])}

    before do
      File.write(source_file.path, "first\n")
      described_class.clear_cache
      described_class.new(object).first_line
      File.write(source_file.path, "second\n")
    end

    after {source_file.close!}

    it 'makes the next read return the changed file' do
      described_class.clear_cache
      expect(described_class.new(object).first_line).to eq("second\n")
    end

    it 'returns the cached lines of a file that changed, until the cache is cleared' do
      expect(described_class.new(object).first_line).to eq("first\n")
    end
  end
end
