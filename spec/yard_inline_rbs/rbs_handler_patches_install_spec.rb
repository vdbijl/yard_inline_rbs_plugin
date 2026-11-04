# frozen_string_literal: true

RSpec.describe YardInlineRbs::RbsHandlerPatches, '.install' do
  it 'patches the method handler and its type conversion' do
    expect(YARD::Handlers::RBS::MethodHandler.ancestors.first(2))
      .to eq([described_class::MethodTags, YARD::Handlers::RBS::MethodHandler])
  end

  it 'patches methods that YARD still has' do
    handler = YARD::Handlers::RBS::MethodHandler
    expect([handler.private_method_defined?(:apply_signature_tags),
            handler.singleton_class.method_defined?(:rbs_type_to_yard_types)]).to eq([true, true])
  end

  it 'patches the type conversion of the method handler class' do
    expect(YARD::Handlers::RBS::MethodHandler.singleton_class.ancestors.first)
      .to be(described_class::TypeConversion)
  end
end
