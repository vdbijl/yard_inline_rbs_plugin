# frozen_string_literal: true

RSpec.describe YardErrors, :yard_errors do
  describe '.messages' do
    context 'when the plugin raises while YARD parses a docstring' do
      before do
        allow(YardInlineRbs::TagInjector).to receive(:new)
                                         .and_raise(NoMethodError, 'boom')
      end

      it 'returns the error that YARD logs instead of raising' do
        YARD::Logger.instance.enter_level(YARD::Logger::FATAL) do
          YARD.parse_string("# Doc\ndef a; end")
        end
        expect(described_class.messages).to include(/boom/)
      end
    end
  end
end
