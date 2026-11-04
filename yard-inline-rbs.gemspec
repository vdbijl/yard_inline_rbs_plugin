# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name        = 'yard-inline-rbs'
  s.version     = '0.1.0'
  s.summary     = 'YARD plugin: use inline RBS type annotations in documentation'
  s.authors     = ['yard-inline-rbs contributors']
  s.homepage    = 'https://github.com/vdbijl/yard_inline_rbs_plugin'
  s.license     = 'MIT'
  s.files       = Dir['lib/**/*', 'LICENSE', 'README.md', 'CHANGELOG.md']
  s.require_paths = ['lib']
  s.required_ruby_version = '>= 3.3'

  s.add_dependency 'rbs', '>= 3.0'
  s.add_dependency 'yard', '>= 0.9.45'
  s.metadata['rubygems_mfa_required'] = 'true'
  s.metadata['source_code_uri'] = 'https://github.com/vdbijl/yard_inline_rbs_plugin'
  s.metadata['changelog_uri'] =
    'https://github.com/vdbijl/yard_inline_rbs_plugin/blob/main/CHANGELOG.md'
  s.metadata['bug_tracker_uri'] = 'https://github.com/vdbijl/yard_inline_rbs_plugin/issues'
end
