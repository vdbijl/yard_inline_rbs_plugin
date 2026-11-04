# yard-inline-rbs

A YARD plugin that uses [inline RBS] type annotations in the generated documentation, so types are
written once: Steep checks them, YARD documents them.

Without the plugin, a typed and documented method needs two type annotations that easily drift
apart:

```ruby
# @param name [String] who to greet
# @return [Array<String>]
# @rbs name: String
# @rbs return: Array[String]
def greet(name); end
```

With the plugin, the RBS annotations are enough:

```ruby
# Greets someone.
# @rbs name: String -- who to greet
# @rbs return: Array[String] -- the greetings
def greet(name); end
```

YARD then documents `@param name [String] who to greet` and
`@return [Array<String>] the greetings`. The RBS types replace any YARD types for the same
parameter or return value, and the `@rbs` lines are removed from the description. A YARD tag
keeps its description when the annotation has none; this includes `@yield` and `@yieldreturn`.
A parameter, the return value or the block that is typed twice, such as by an `@rbs` tag and a
`#:` line, gets a warning; the first annotation wins, and `@rbs` tags come before `#:` lines.

## Installation

Add the gem to the Gemfile of the project to document:

```ruby
gem 'yard-inline-rbs', path: '../yard_inline_rbs_plugin'
```

Enable the plugin in its `.yardopts`:

```
--plugin inline-rbs
```

Then run `yard doc` as usual.

## Regular RBS files

The plugin also documents the types in regular `.rbs` files. YARD parses `sig/**/*.rbs` by
default; when `.yardopts` lists files, add them to the list:

```
--plugin inline-rbs
lib/**/*.rb
sig/**/*.rbs
```

The methods, attributes and constants of a `.rbs` file get the same tags as inline annotations:
`@param`, `@return`, `@yield` and `@yieldreturn`, with types in YARD notation (`Array<String>`,
not `Array[String]`). A method with several signatures gets an `@overload` tag for each.
Parameters take the name of the Ruby parameter, also when the signature names them differently:
Steep does not check RBS parameter names. Without a Ruby method, they keep the name in the
signature, or are called `arg0`, `arg1`, ...

YARD 0.9.45 or later is required, because it parses the `.rbs` files into objects. The
plugin parses the `.rbs` files before the Ruby files and writes the tags once all files are
parsed, so the order of the files in `.yardopts` does not matter.

- **Existing tags win.** A `.rbs` declaration only adds types that are missing, so a type in the
  Ruby docstring or an inline annotation takes precedence over `sig/`. A tag with only a
  description, such as `@param name The name.`, gets the type of the `.rbs` file. This differs from inline
  annotations, which replace YARD types. A type that an inline annotation and a `.rbs` file both
  declare gets a warning, such as `lib/shop.rb:7: two RBS annotations for the return type, one
  in sig/shop.rbs`; a YARD type such as `@param [String] name` does not.
- **Comments in `.rbs` files** show up only where the Ruby declaration has no description. A
  Ruby comment with only annotations, such as a trailing `#: String`, has no description.
- `def self?.name` is not supported: YARD does not create objects for it.

## Supported annotations

The plugin follows the inline RBS syntax built into the rbs gem, as specified in [inline RBS].

| Annotation | Result |
|---|---|
| `# @rbs (Integer, ?String, *Symbol, name: String, **bool) -> void` | `@param` for every parameter, `@return` |
| `#: (Integer) -> String` above a method | `@param`, `@return` |
| `# @rbs (String) { (Integer) -> void } -> void` | `@param`, `@yield`, `@yieldreturn`, `@return` |
| `# @rbs { () -> void } -> void`, without parameter list | `@yield`, `@yieldreturn`, `@return` |
| `# @rbs (Integer) -> String`, then `#    \| (Float) -> Float` on the next line | An `@overload` tag for each signature, and no `@param` or `@return` on the method itself |
| A signature that continues on indented comment lines (`#   -> String`) | As on one line |
| `# @rbs name: String -- description` | `@param` with description |
| `# @rbs *names: String`, `# @rbs **options: bool`, also unnamed | `@param` for the splat or keyword rest |
| `# @rbs &block: (String) -> void`, also optional (`? (…) -> …`) | `@yield`, `@yieldreturn` |
| `# @rbs return: String -- description` | `@return` with description |
| `def name #: String` and `def name = value #: String` | `@return` |
| `attr_reader :name #: String`, also `attr_writer` and `attr_accessor` | `@return` on the reader, `@param` on the writer |
| `ITEMS = [] #: Array[String]` | `@return` on the constant |

A description after `--` may continue on the next lines, or start on the line below a trailing
`--`. Annotations that only instruct the type checker are removed without a trace: `@rbs skip`,
`@rbs ...`, `@rbs module-self:`, `#: class-alias`, `#: module-alias` and generic superclass
comments such as `class StringArray < Array #[String]`.

RBS types are converted to the YARD notation:

| RBS | YARD |
|---|---|
| `Integer?` | `Integer, nil` |
| `String \| Symbol` | `String, Symbol` |
| `bool` | `Boolean` |
| `Array[String]` | `Array<String>` |
| `Hash[Symbol, Integer]` | `Hash{Symbol => Integer}` |
| `Comparable & Enumerable[Integer]` | `Comparable & Enumerable<Integer>` |
| `Shop::path` (alias), `_Each[Integer]` (interface) | `Shop::path`, `_Each<Integer>` |
| `[Integer, String]` (tuple) | `Array(Integer, String)` |
| `{ id: Integer, name: String }` (record) | `Hash{Symbol => Integer, String}` |
| `^(Integer) -> String` (proc) | `Proc` |

A record loses the names of its keys: YARD has no notation for them. A tuple or record without
elements (`[]`, `{ }`) is `Array` or `Hash`.

When an annotation cannot be parsed or is not supported, the plugin logs a warning with the file
and line, and still generates the documentation:

```
[warn]: [yard-inline-rbs] lib/foo.rb:12: could not parse RBS type 'BadType!!!'
```

## Limitations

Some Ruby constructs, such as `Struct.new` and `Data.define`, cannot be typed with inline RBS
yet. See [docs/limitations.md](docs/limitations.md) for what is not supported and why.

Not yet implemented in the plugin itself:

- A `#:` signature cannot have overloads; Steep rejects them too. Use `@rbs` for overloads.
- A hand-written `@overload` tag wins: the overloads of an annotation or of a `.rbs` file are not
  added next to it.
- RBS types without a YARD equivalent are shown as written, e.g. `singleton(Foo)`, `boolish` and
  `instance`.
- YARD has no notation for nested lists. A tuple groups an optional or a union element:
  `[Integer?, String]` is `Array((Integer, nil), String)`. A record joins the types of its values
  into one list, so `{ a: Integer?, b: String }` is `Hash{Symbol => Integer, nil, String}`.
- Instance variable annotations (`@rbs @name: String`) are reported as unsupported, because YARD
  does not document instance variables.

## Development

```shell
bundle install
bundle exec rake
```

`rake` runs all checks: RuboCop, Steep, the dependency audit, the specs with coverage minimums,
and YARD documentation and RSpec coverage. [AGENTS.md](AGENTS.md#running-checks) explains each
check and how to run one on its own.

The plugin hooks into `YARD::DocstringParser.after_parse` (see `lib/yard_inline_rbs/plugin.rb`):

- `TagInjector` collects the annotations of a docstring and replaces them with YARD tags.
- `RbsCommentParser` parses the annotations with the rbs gem.
- `RbsFunctionTypes` converts the parameters, return type and block of a method type.
- `RbsDescription` splits an annotation into its type and `--` description.
- `RbsTypeFormatter` converts RBS types into YARD type strings.
- `RbsFileTags` writes the types of `.rbs` files onto the YARD objects after all files are parsed,
  using `MemberTags` and `ResultApplier`.

[inline RBS]: https://github.com/ruby/rbs/blob/master/docs/inline.md

## License

Released under the [MIT License](LICENSE).
