# frozen_string_literal: true

RSpec.describe YardInlineRbs::AnnotationWarnings do
  let(:warnings) {described_class.new('lib/widget.rb:3')}

  def result(parse_errors: [], unsupported_annotations: [], duplicate_annotations: [])
    YardInlineRbs::ParseResult.new.tap do |result|
      result.parse_errors.concat(parse_errors)
      result.unsupported_annotations.concat(unsupported_annotations)
      result.duplicate_annotations.concat(duplicate_annotations)
    end
  end

  before {described_class.clear_logged}

  describe '.clear_logged' do
    before {warnings.report(result(parse_errors: ['BadType!!!']))}

    it 'makes the next report log the same warning again' do
      described_class.clear_logged
      expect(YARD::Logger.instance).to receive(:warn)
        .with("[yard-inline-rbs] lib/widget.rb:3: could not parse RBS type 'BadType!!!'")
      warnings.report(result(parse_errors: ['BadType!!!']))
    end

    it 'returns nil, so a before_parse_file callback does not stop the parse' do
      expect(described_class.clear_logged).to be_nil
    end
  end

  describe '#initialize' do
    it 'does not log anything' do
      expect(YARD::Logger.instance).not_to receive(:warn)
      described_class.new('lib/widget.rb:3')
    end
  end

  describe '#report_rbs_file_duplicates' do
    it 'warns with the location and the .rbs file' do
      expect(YARD::Logger.instance).to receive(:warn)
        .with('[yard-inline-rbs] lib/widget.rb:3: two RBS annotations for the return type, '\
              'one in sig/widget.rbs')
      warnings.report_rbs_file_duplicates(['the return type'], 'sig/widget.rbs')
    end
  end

  describe '#report' do
    context 'with something that was annotated twice' do
      it 'warns with the location' do
        expect(YARD::Logger.instance).to receive(:warn)
          .with("[yard-inline-rbs] lib/widget.rb:3: two RBS annotations for parameter 'count'")
        warnings.report(result(duplicate_annotations: ["parameter 'count'"]))
      end
    end

    context 'with an annotation that could not be parsed' do
      it 'warns with the location' do
        expect(YARD::Logger.instance).to receive(:warn)
          .with("[yard-inline-rbs] lib/widget.rb:3: could not parse RBS type 'BadType!!!'")
        warnings.report(result(parse_errors: ['BadType!!!']))
      end
    end

    context 'with an unsupported annotation' do
      it 'warns with the location' do
        expect(YARD::Logger.instance).to receive(:warn)
          .with("[yard-inline-rbs] lib/widget.rb:3: unsupported RBS annotation '@count: Integer'")
        warnings.report(result(unsupported_annotations: ['@count: Integer']))
      end
    end

    context 'with a warning that was already logged for the same location' do
      before {warnings.report(result(parse_errors: ['BadType!!!']))}

      it 'does not log it again' do
        expect(YARD::Logger.instance).not_to receive(:warn)
        described_class.new('lib/widget.rb:3').report(result(parse_errors: ['BadType!!!']))
      end
    end

    context 'without problems' do
      it 'does not log anything' do
        expect(YARD::Logger.instance).not_to receive(:warn)
        warnings.report(result)
      end
    end
  end
end
