# frozen_string_literal: true

require 'open3'
require 'tmpdir'

# The checks of `rake prerelease`, which has the tasks. Not part of the gem.
module Prerelease
  GEMSPEC = 'yard-inline-rbs.gemspec'
  FIXTURE = 'spec/fixtures/shop'

  # @return [<String>] What the built gem must contain.
  REQUIRED_FILES = %w[lib/yard-inline-rbs.rb lib/yard_inline_rbs/plugin.rb
                      LICENSE README.md CHANGELOG.md].freeze

  # @return [Regexp] What the built gem must not contain.
  UNWANTED_PATTERN = %r{\A(spec|script|sig|docs?|\.github)/|\A\.}

  # Prints the problems and stops the task, if there are any.
  # @param problems [Array<String>]
  def self.fail_on(problems)
    return if problems.empty?

    abort(problems.map {|problem| "  - #{problem}"}.unshift('Prerelease check failed:').join("\n"))
  end

  # @return [Array<String>] What is wrong with the repository as a release commit.
  def self.repository_problems
    version = Gem::Specification.load(GEMSPEC).version
    status, git_problem = git('status', '--porcelain')
    return [git_problem] if git_problem

    problems = []
    problems << 'the working tree has uncommitted changes' if !status.empty?
    problems.concat(version_problems(version))
    problems.concat(changelog_problems(version))
  end

  # A git command that fails, for example outside a repository, is a problem, not an empty answer.
  # @return [(String, String?)] The output, and what went wrong, if anything.
  def self.git(*arguments)
    output, status = Open3.capture2e('git', *arguments)
    return [output, nil] if status.success?

    [output, "git #{arguments.join(' ')} failed: #{output.strip}"]
  end
  private_class_method :git

  # @return [Array<String>]
  def self.version_problems(version)
    output, git_problem = git('tag', '--list', 'v*')
    return [git_problem] if git_problem

    versions = output.split.map {|tag| tag.delete_prefix('v')}.select {|tag| Gem::Version.correct?(tag)}
    latest = versions.map {|tag| Gem::Version.new(tag)}.max
    return [] if latest.nil? || version > latest

    ["version #{version} is not newer than the latest tag v#{latest}"]
  end
  private_class_method :version_problems

  # @return [Array<String>]
  def self.changelog_problems(version)
    changelog = File.read('CHANGELOG.md')
    problems = []
    if !changelog.match?(/^## #{Regexp.escape(version.to_s)}(?:\s|$)/)
      problems << "CHANGELOG.md has no '## #{version}' heading"
    end
    problems << "CHANGELOG.md has a '## Unreleased' heading" if changelog.match?(/^## Unreleased/)
    problems
  end
  private_class_method :changelog_problems

  # @return [Array<String>] What is wrong with the built gem.
  def self.package_problems
    Dir.mktmpdir('prerelease') do |dir|
      gem_file = File.join(dir, 'plugin.gem')
      output, status = Open3.capture2e('gem', 'build', GEMSPEC, '--output', gem_file)
      next ["gem build failed:\n#{output}"] if !status.success?

      unpacked = unpack(gem_file, dir)
      content_problems(unpacked) + packaged_plugin_problems(unpacked, dir)
    end
  end

  # @return [String] The directory with the files of the gem.
  def self.unpack(gem_file, dir)
    system('gem', 'unpack', gem_file, '--target', dir, out: File::NULL) or abort 'gem unpack failed'
    File.join(dir, File.basename(gem_file, '.gem'))
  end
  private_class_method :unpack

  # @return [Array<String>]
  def self.content_problems(unpacked)
    files = Dir.glob('**/*', File::FNM_DOTMATCH, base: unpacked)
               .select {|f| File.file?("#{unpacked}/#{f}")}
    (REQUIRED_FILES - files).map {|file| "the gem lacks #{file}"} +
      files.grep(UNWANTED_PATTERN).map {|file| "the gem contains #{file}"}
  end
  private_class_method :content_problems

  # Runs `yard doc` with only the unpacked gem on the load path, so the repository's own lib/
  # cannot hide a file that is missing from the gem.
  # @return [Array<String>]
  def self.packaged_plugin_problems(unpacked, dir)
    html = File.join(dir, 'html')
    status = yard_doc(File.join(unpacked, 'lib'), html)
    if !status.success?
      return ["yard doc with the packaged plugin failed (exit #{status.exitstatus})"]
    end

    page = File.join(html, 'Shop.html')
    return [] if File.exist?(page) && File.read(page).include?('the item to add')

    ['the packaged plugin adds no annotation types or descriptions to the HTML']
  end
  private_class_method :packaged_plugin_problems

  # @return [Process::Status]
  def self.yard_doc(lib_dir, output_dir)
    Bundler.with_unbundled_env do
      Open3.capture2e({ 'RUBYLIB' => lib_dir }, 'yard', 'doc', '--quiet', '--no-save',
                      '--output-dir', output_dir, chdir: File.expand_path(FIXTURE)).last
    end
  end
  private_class_method :yard_doc

  # Stops the task if mutaruby is missing or mutants survive. mutaruby is not in the Gemfile, so it
  # runs outside the bundle; its test command starts its own `bundle exec`.
  def self.mutation_testing
    Bundler.with_unbundled_env do
      system('mutaruby', '--version', out: File::NULL) or
        abort 'mutaruby is not installed: run gem install mutaruby'
      system('mutaruby', '--test', 'bundle exec rspec --fail-fast', '--copy-exclude', 'doc',
             '--copy-exclude', '.yardoc') or abort 'Mutation testing found surviving mutants'
    end
  end
end
