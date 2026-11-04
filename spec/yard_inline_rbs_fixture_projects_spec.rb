# frozen_string_literal: true

require 'fileutils'
require 'open3'
require 'tmpdir'

# Runs YARD in a new process inside a copy of a project in spec/fixtures, as `yard doc` would:
# with .yardopts, `--plugin` and real files. This checks what YARD.parse_string cannot, such as
# the files YARD picks by default and the order in which it parses them.
RSpec.describe YardInlineRbs do
  describe 'yard run in a fixture project' do
    let(:shop_files) {['.', '.yardopts', 'lib', 'lib/shop.rb', 'sig', 'sig/shop.rbs']}
    let(:shop_documentation) do
      <<~TEXT
        [warn]: [yard-inline-rbs] lib/shop.rb:24: could not parse RBS type 'Array['
        [warn]: [yard-inline-rbs] lib/shop.rb:6: two RBS annotations for the return type, one in sig/shop.rbs
        [warn]: [yard-inline-rbs] lib/shop.rb:18: two RBS annotations for parameter 'width', one in sig/shop.rbs
        [warn]: [yard-inline-rbs] lib/shop.rb:18: two RBS annotations for the return type, one in sig/shop.rbs
        Shop
          A shop.
        Shop#add
          Adds an item.
          @param item [String] the item to add
          @return [Boolean]
        Shop#broken
          Has an annotation that is not valid RBS.
          @param item [untyped]
          @return [void]
        Shop#clear
          Empties the shop.
          @return [void]
        Shop#label
          Typed inline and in sig/shop.rbs: the inline annotation wins, with a warning.
          @param width [Integer]
          @return [String]
        Shop#name
          The name of the shop.
          @return [String]
        Shop#remove
          Removes items. Typed in sig/shop.rbs only.
          @param item [String]
          @param count [Integer]
          @return [void]
      TEXT
    end

    # @param project [String] The name of a directory in spec/fixtures.
    # @param arguments [Array<String>] Passed to YARD, e.g. the files to parse.
    # @return [(String, String, Integer, Array<String>)] The stdout, stderr and exit status of
    #   the run, and the files in the project afterwards.
    def run_yard(project, *arguments)
      Dir.mktmpdir do |directory|
        FileUtils.cp_r(File.join(__dir__, 'fixtures', project, '.'), directory)
        stdout, stderr, status =
          Open3.capture3(Gem.ruby, '-I', File.expand_path('../lib', __dir__),
                         File.join(__dir__, 'fixtures', 'print_registry.rb'), *arguments,
                         chdir: directory)
        [stdout, stderr, status.exitstatus, Dir.glob('**/*', File::FNM_DOTMATCH, base: directory)]
      end
    end

    context 'when .yardopts lists no files, so YARD parses lib/ and then sig/' do
      it 'documents the types of the Ruby and the .rbs files, and writes no files' do
        expect(run_yard('shop')).to eq([shop_documentation, '', 0, shop_files])
      end
    end

    context 'when the files are listed with the Ruby files first' do
      it 'documents the same types' do
        expect(run_yard('shop', 'lib/**/*.rb', 'sig/**/*.rbs'))
          .to eq([shop_documentation, '', 0, shop_files])
      end
    end

    context 'when the files are listed with the .rbs files first' do
      it 'documents the same types' do
        expect(run_yard('shop', 'sig/**/*.rbs', 'lib/**/*.rb'))
          .to eq([shop_documentation, '', 0, shop_files])
      end
    end
  end
end
