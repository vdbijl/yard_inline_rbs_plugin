# frozen_string_literal: true

RSpec.describe YardInlineRbs, '.warn' do
  it 'logs a YARD warning that names the plugin' do
    expect(YARD::Logger.instance).to receive(:warn).with('[yard-inline-rbs] lib/a.rb:3: oops')
    described_class.warn('lib/a.rb:3: oops')
  end
end
