# Lessons from yard-rspec-coverage

Lessons from a review and bug hunt in the sibling plugin `../yard_rspec_plugin`
(yard-rspec-coverage), November 2026, and how they apply here. Ordered by expected payoff.

## Status (2026-11-03)

All lessons are applied here. What they found in this plugin:

| Bug | Found by |
|---|---|
| Duplicate warnings, up to three per annotation, for attributes and `attr_accessor` | Lesson 4: a warning spec for each rescue |
| `@rbs { () -> void } -> void` (no parameter list) rejected | Lesson 3: corpus run on a real project |
| Warning location and trailing `#:` taken from the `.rbs` file when it has a comment | Lesson 3: corpus run with `sig/` |
| `.rbs` description lost when the Ruby comment only holds annotations | Same probe |
| Signatures continued on the next line not parsed; `#:` continuation and overload lines left in the description | Lesson 6: annotations with parts missing |
| Empty `#:` left a `:` in the description; empty `#:` and `@rbs` gave no warning | Same |
| `#:` overloads documented, although Steep rejects them | Checking the continuation shapes against Steep |

Coverage was already 100% for branches and found none of these.

## What found the bugs there

| Bug | Found by | Did coverage help? |
|---|---|---|
| `Config.files` added to `.yardopts` instead of replacing it | Running it in a real project | No: the line was covered and its spec passed |
| A blockless `it` counted as covered | Asking what input reaches an uncovered branch | Yes |
| README wrong about interpolated descriptions | The same question, for another uncovered branch | Yes |
| Crash on a describe of a constant (`Foo = Class.new`) | A corpus run over a real project | No: the crashing call was covered |
| `false` passed as a block body | A logged YARD error during a refactor | No |

Coverage found two of the five, and even then the bug came from asking which real input reaches
the branch. It cannot see missing code, and covered is not the same as checked. Running the
plugin on real input found most bugs.

## 1. Make YARD errors fail the specs

YARD catches an exception raised by a handler and only logs `[error]: ...`. A spec that runs the
crashing code still passes. In yard-rspec-coverage a spec for the crash passed while the bug was
present. `spec/spec_helper.rb` here sets the log level to `ERROR`, so these errors are printed,
but nothing fails on them.

**Apply:** add a global hook in `spec_helper.rb` that fails an example when `YARD::Logger`
receives `error` (except in the specs that test logged errors on purpose).

## 2. Test with real file lists and real projects, not only `parse_string`

The specs use `YARD.parse_string`; none parses a file list or runs `yard` in a subprocess. Two of
the bugs only existed in a real project run: how `.yardopts` combines with given files, and a
constant registered as `ConstantObject`. Behaviour that differs between `parse_string` and
`YARD.parse(files)` stays invisible; `declaration_source.rb` already has a `(stdin)` special case.

**Apply:** add minimal projects under `spec/fixtures/` (`.yardopts`, `--plugin`, `lib/`, `sig/`)
and a spec that runs `yard` in each with `Open3.capture3(..., chdir: project_dir)`. Compare the
full stdout, stderr and exit status. What came with that in yard-rspec-coverage:

- `.rspec`: `--exclude-pattern spec/fixtures/**/*_spec.rb`, so RSpec does not run fixture specs.
- `.rubocop.yml`: `AllCops: Exclude: [spec/fixtures/**/*]`.
- Keep paths relative and run inside the fixture directory, so the output is stable.
- Check that a run leaves nothing behind in the fixture directory, such as `.yardoc/` or `doc/`.
- Check that the spec fails without the fix: temporarily revert it and run the spec.
- A subprocess does not count towards SimpleCov; keep the in-process specs as well.

## 3. Run a corpus check on a real project

Use a real code base that has `@rbs` annotations. Running the plugin over it with Ruby's
`Coverage` module in branch mode shows which guards are ever reached, and finds crashes. Also count the parse errors that the plugin rescues and turns into warnings
(`RBS::ParsingError` in `type_parser.rb` and `rbs_file_tags.rb`).

Run it with this project's Gemfile from a scratch directory, not inside a corpus repo:

```ruby
# Usage: BUNDLE_GEMFILE=.../Gemfile bundle exec ruby corpus.rb PLUGIN_LIB PROJECT_DIR...
require 'coverage'
Coverage.start(branches: true)
plugin_lib = File.expand_path(ARGV.shift)
$LOAD_PATH.unshift(plugin_lib)
require 'yard'
require 'yard-inline-rbs'
YARD::Logger.instance.level = YARD::Logger::FATAL

ARGV.each do |project|
  files = Dir[File.join(project, '{lib,app}/**/*.rb')].reject {|file| file.include?('/vendor/')}
  YARD::Registry.clear
  begin
    YARD.parse(files, [], YARD::Logger::FATAL)
  rescue StandardError => e
    puts "#{project}: parse aborted: #{e.class}: #{e.message}"
  end
  puts "#{File.basename(project)}: #{files.size} files, " \
       "#{YARD::Registry.all(:method).size} methods"
end

puts "\nBranches never taken on the corpus:"
Coverage.result.each do |file, data|
  next if !file.start_with?(plugin_lib)

  data[:branches].each do |(type, *), branches|
    branches.each do |(kind, _, line, *), hits|
      puts "  #{file.delete_prefix("#{plugin_lib}/")}:#{line} #{type} -> #{kind}" if hits.zero?
    end
  end
end
```

To see YARD errors and the plugin's warnings, lower the log level, or prepend a module to the
handler that prints the statement when an exception passes through. A branch that is reached
needs a spec for the input that reaches it; a branch that is never reached is a candidate for
removal, after checking YARD's or RBS's source that it really cannot happen.

## 4. Look hard at silent rescues

`declaration_source.rb` has `rescue StandardError` returning `nil`. That pattern turns a bug into
missing output without a message, as YARD's own logging did in yard-rspec-coverage.

**Apply:** narrow it to the errors that are expected (probably `SystemCallError`), or log them.
For each `RBS::ParsingError` rescue, have a spec that shows the user gets a visible warning.

## 5. 100% branch coverage is not proof

The branch minimum is already 100%, so coverage gives no new signal. The remaining risk is in
wrong assumptions about YARD and RBS. Read the gem source when behaviour matters (in
yard-rspec-coverage, `YARD::CLI::Yardoc#parse_files` settled the `.yardopts` question in one
read) and run on real code instead of reasoning about it.

Examples to check: the `&.` in `result_applier.rb` (`replaced&.text`) and
`rbs_function_types.rb` (`param.name&.to_s`, `rest.name&.to_s`). `param.name` can be nil for
unnamed RBS parameters; whether `replaced` can be nil is less clear. Settle each with a real
annotation: a spec if it occurs, removal if it cannot.

## 6. Check how the gem handles input without its usual parts

In yard-rspec-coverage, any `describe`, `context` or `it` could appear without a block, and the
common pattern `node.last.last` then returned the last argument or `false` instead of a block
body. Collecting that shape in one helper (`block_body_of`, nil without a block) fixed a crash and
removed a dozen guards.

**Apply:** the RBS equivalents are annotations with parts missing: no return type, unnamed
parameters, an empty `#:`, an overload without a block, a `@rbs` line without a type. Handle each
shape in one place instead of with `&.` spread across the code.

## 7. Process

- **Write the spec first and check it fails for the right reason.** Twice a spec passed with the
  bug still present. Temporarily removing the fix to watch the spec fail takes seconds.
- **Prefer the fix in code over documenting a limitation** when the code is easy to fix: the
  README described interpolation behaviour that the code did not have.
- **The sandbox blocks `build.sh` at `bundle:audit:update`** (it writes
  `~/.local/share/ruby-advisory-db`). Either run `bundle exec rake default` directly, or allow that
  folder in the sandbox settings.
