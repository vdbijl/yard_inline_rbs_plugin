# yard-inline-rbs plugin — agent briefing

## What this is

A YARD plugin that reads inline RBS annotations (`# @rbs ...`, `#: ...` and trailing `#: Type`
comments) and turns them into the YARD tags `@param`, `@return`, `@yield` and `@yieldreturn`.
The types in the generated documentation then come from the same annotations that Steep checks.

## File layout

```
lib/
  yard-inline-rbs.rb              # Entry point: requires everything, documents the module
  yard_inline_rbs/
    plugin.rb                     # Defines the @rbs tag, installs the hooks
    rbs_handler_patches.rb        # Patches YARD's .rbs handlers (no tags, our type conversion)
    rbs_file_tags.rb              # RbsFileTags: .rbs declarations to tags, after all files are parsed
    member_tags.rb                # MemberTags: tags one YARD object from RBS types
    overload_text.rb              # OverloadText: the text of an @overload tag
    result_applier.rb             # ResultApplier: ParseResult to tags, for any tag target
    object_tags.rb                # ObjectTags: gives a YARD object the tags API of a docstring parser
    tag_injector.rb               # TagInjector: applies the parsed annotations to a docstring parser
    rbs_comment_parser.rb         # RbsCommentParser: collects the annotations into a ParseResult
    inline_annotations.rb         # InlineAnnotations: the `#:` lines and the trailing `#:` comment
    type_parser.rb                # TypeParser: RBS strings to YARD types, records parse errors
    parse_result.rb               # ParseResult, the value objects it holds, Annotated keys
    rbs_type_formatter.rb         # RbsTypeFormatter: RBS type AST to YARD type string
    rbs_function_types.rb         # RbsFunctionTypes: parameter and return types of a function type
    rbs_description.rb            # RbsDescription: splits `Type -- description`
    parameter_names.rb            # ParameterNames: the parameter names of a method object
    declaration_source.rb         # DeclarationSource: the declaration line of an object
    annotation_warnings.rb        # AnnotationWarnings: warns about unusable annotations
    inline_types.rb               # InlineTypes: what an object's inline annotations typed

spec/
  spec_helper.rb
  support/yard_errors.rb          # Records YARD's logged errors; spec_helper fails on them
  yard_inline_rbs_spec.rb         # System specs: parse Ruby source, inspect the YARD registry
  yard_inline_rbs_fixture_projects_spec.rb  # Runs YARD in a subprocess in each fixture project
  fixtures/
    print_registry.rb             # Run in a fixture: YARD CLI with .yardopts, prints all tags
    <project>/                    # .yardopts, lib/, sig/; excluded from .yardopts and RuboCop
  yard_inline_rbs/
    <class>_spec.rb               # One unit spec per class, named after the class
```

## How the plugin works end-to-end

1. `plugin.rb` registers the `@rbs` tag and an `after_parse` callback on
   `YARD::DocstringParser`. YARD calls it for every docstring it parses.
2. `TagInjector#inject` collects the `@rbs` tags and the description lines starting with `: `.
   `RbsCommentParser` parses them, plus the trailing `#:` comment on the declaration line, into
   a `ParseResult`. Values from `@rbs` tags win over inline annotations.
3. `TagInjector` removes the annotation lines and `@rbs` tags from the docstring, also when they
   could not be parsed, and injects the typed tags. RBS types replace existing YARD types.
4. `AnnotationWarnings` logs a YARD warning for each annotation that is invalid or unsupported,
   and for each parameter, return value or block that is typed twice. `ParseResult` keeps the
   first annotation and records the duplicates. `ResultApplier` records a named and a positional
   annotation of the same parameter, which only the parameter names show, so the warnings come
   after the tags are applied. A trailing `#:` that is also the docstring is read only once.

## Regular RBS files

YARD 0.9.45+ parses `.rbs` files into objects and adds string-based tags. `RbsHandlerPatches` turns
off its method tags and replaces its type conversion. `RbsFileTags` runs from `after_parse_list`,
re-parses the `.rbs` files with the rbs gem and applies the declarations through `MemberTags` and
`ResultApplier` with `keep_existing: true`: tags that already have types (docstring, inline
annotation) win. `TagInjector` stores on each object what its inline annotations typed and where,
through `InlineTypes`; YARD replaces it with the docstring and keeps it in its cache. A kept tag
from an inline annotation is reported as a duplicate of the `.rbs` declaration, and a type from a
YARD tag is not. A `before_parse_list` callback moves the `.rbs` files before the Ruby files,
because YARD replaces the whole docstring (description and tags) of an object whenever it parses a
comment later.

## Adding support for a new annotation

Add the parsing to `RbsCommentParser` (an `@rbs` tag) or `InlineAnnotations` (`#:` comments),
put the result in `ParseResult`, and inject the tag in `ResultApplier`. Parse types through
`TypeParser`, so invalid input is recorded as a parse error instead of raised. Add the type
conversion to `RbsTypeFormatter` when a new RBS type needs a YARD spelling.

## Code style

- Put `private_class_method :name` on the line directly below the `end` of the class method it
  hides, not in one list at the end of the class.

## Testing conventions

- TDD: write the failing spec first, then implement.
- Describe what a method returns as `it 'returns ...'`, not `it 'is ...'`.
- Every public method, including `#initialize`, needs a `describe '#method'` or
  `describe '.method'` spec. The `yard:rspec_coverage` task fails otherwise.
- Use `YARD::Registry.clear` + `YARD.parse_string(source)` to set up registry state. Use a
  `Tempfile` and `YARD.parse(path)` when the file matters, e.g. for trailing `#:` comments.
- Set message expectations (`expect(...).to receive(...)`) before the action, not after. RuboCop
  enforces this with `RSpec/MessageSpies`.
- Do not disable a RuboCop cop to make a spec pass; find the pattern the cop asks for.
- YARD rescues an exception raised in a handler (including our `after_parse` callback) and only
  logs `[error]: ...`. `spec/support/yard_errors.rb` records those, and `spec_helper.rb` fails the
  example on them. Tag an example `:yard_errors` only when it logs an error on purpose.
- When a spec covers a bug, check that it fails for the right reason: revert the fix briefly.
- Behaviour that depends on how YARD picks and orders files, or on `.yardopts` and `--plugin`,
  needs a fixture project. `parse_string` cannot show it. The subprocess does not count towards
  SimpleCov, so keep the in-process specs as well.
- The specs run in random order.

## Running checks

```bash
bundle exec rspec
bundle exec rubocop -A
bundle exec steep check
bundle exec rake    # all checks, see below
```

`rake` (the default task) runs RuboCop, Steep, `bundle:audit`, `spec:coverage`, `yard:coverage` and
`yard:rspec_coverage`. It does not run `yard:doc`, which writes HTML to `doc/`.

- `steep` type checks the inline RBS annotations in `lib/`, see `Steepfile`. YARD ships no types,
  so `sig/yard.rbs` declares the parts of YARD that the gem uses.
- `bundle:audit` (bundler-audit) checks `Gemfile.lock` against a local database of known gem
  vulnerabilities. It does not update that database: run `bundle exec rake bundle:audit:update`
  first to get the latest advisories (this needs network access).
- `spec:coverage` runs the specs with SimpleCov (`COVERAGE=true`). The minimum line and branch
  coverage is set in `spec/spec_helper.rb`. Never lower it without asking.
- `yard:coverage` fails unless everything is documented and YARD logs no warnings.
- `yard:rspec_coverage` fails unless every public method has a spec; the minimum is set in the
  `Rakefile`.
- RuboCop uses its default configuration plus the performance, rake and rspec plugins, see
  `.rubocop.yml` for the few deviations. `.yardopts` selects Markdown through redcarpet and loads
  this plugin and `yard-rspec-coverage` for the project's own documentation.
- Run the entire build via `build.sh`.

## Mutation testing

[mutaruby](https://rubygems.org/gems/mutaruby) mutates `lib/` and runs the specs against each
mutant. It is not part of the build or the Gemfile. A full run takes about 7 minutes:

```bash
mutaruby -t 'bundle exec rspec --fail-fast' --copy-exclude doc --copy-exclude .yardoc
mutaruby -t 'bundle exec rspec --fail-fast' lib/yard_inline_rbs/type_parser.rb  # one file
```

- `.mutaruby-ignore.yml` lists the mutants that cannot change the behaviour, each with its
  reason: memoisation, `private_class_method`, `.freeze`, and `.to_s` that only Steep needs.
  The entries match on the text of the line, so an entry stops matching when its line changes.
- A surviving mutant is a spec to write, or code to remove when it makes no difference. Add an
  ignore entry only for a mutant that no realistic input can tell apart from the original.

## Releasing

`bundle exec rake prerelease` runs the checks of a release commit, see `script/prerelease.rake`:
`prerelease:package` builds the gem and runs `yard doc` with only the unpacked gem,
`prerelease:mutation` runs mutaruby outside the bundle, and `prerelease:repository` needs a clean
git tree, a version newer than the latest `v*` tag, and a `CHANGELOG.md` entry. A `v*` tag runs
`.github/workflows/release.yml`, which publishes with Trusted Publishing.

## Documentation

- Use terse documentation. If the method name is clear, no comments are needed.
- Prefer an explanation with the `@return` over general method documentation, if the return can
  explain the logic.
- Prefer clear describe and it blocks in RSpec over documentation.
- This project documents itself with its own plugin: `# @rbs ...` annotations count as
  documentation, and are turned into tags by `yard`.
- Add inline RBS type annotations to all methods

## Inline RBS in this gem

Every method in `lib/` has an inline `# @rbs` signature, and Steep checks them. Constants and
attributes use a trailing `#: Type`. RuboCop allows these through `AllowRBSInlineAnnotation` and
`AccessorGrouping: separated` in `.rubocop.yml`; without them `rubocop -A` rewrites `#:` to `# :`.
Inline RBS cannot see `Struct.new` classes, so value objects are plain classes. Put the
`# @rbs @ivar: Type` comments before a declaration that has its own comment, or YARD reads them
as its docstring.

## Gotchas

- A signature may continue on indented comment lines, checked with Steep 2.1: `#   -> String`,
  a parameter list over several lines whose closing `)` line is indented, a union `#   | Float`,
  and for `@rbs` (not `#:`) an overload `#    | (Float) -> Float`. An unindented line ends the
  annotation, so `# ) -> String` makes the signature invalid, and a continuation line that is
  not RBS (without `--`) does too. `RbsDescription.split` joins the lines of the first overload;
  `RbsDescription.overloads` returns every overload, which become `@overload` tags through
  `ParseResult#add_overloads` and `ResultApplier`, as for `.rbs` files. `TagInjector` collects
  the indented lines below a `#:` line with it, and `InlineAnnotations` reports a `#:` overload
  as invalid.
- `object.file` and `object.line` are those of the first declaration *with a comment*. Because
  the `.rbs` files are parsed first, that is the `.rbs` file when its declaration has a comment.
  `DeclarationSource#location` uses the handler's statement instead, or the first Ruby file.
- YARD replaces an object's docstring with every comment it parses, also with one that only
  holds annotations. `TagInjector` then keeps the description already on the object, e.g. the
  one from the `.rbs` file.
- `writer?` is not set yet when the `after_parse` callback runs, so `TagInjector` recognises a
  writer by the `=` at the end of its name.
- YARD generates a synthetic source for `attr_*` methods. `DeclarationSource` reads the original
  line from the file instead, which is why a trailing `#:` comment works on them. It falls back
  to the object's source for `YARD.parse_string`, where there is no file.
- YARD takes the trailing comment of a statement as the docstring of the next statement when
  that has no comment above it: after a statement with a comment above it, or after a statement
  over several lines. `DeclarationSource#comment_of_earlier_statement?` detects this, and
  `TagInjector` then skips the `#:` lines of that docstring; they belong to the earlier statement.
  A trailing `#:` is only read from the first line of a statement, so a constant over several
  lines gets no type from it.
- YARD reads a comment after a generic superclass (`class StringArray < Array #[String]`) as the
  class description. `TagInjector` removes it from the description.
- `Gemfile.lock` and the gems are managed by RVM through `.ruby-version` and `.ruby-gemset`;
  do not edit these without asking.
