# Limitations

yard-inline-rbs turns inline RBS annotations into YARD tags. It can only document what inline RBS
can express. This page lists what inline RBS cannot express yet, and why the plugin therefore does
not support it.

Status as of 2026-10-29: rbs 4.2.0 and Steep 2.1.0, the latest releases, and their master branches.

## Inline RBS implementations

There are two implementations of inline RBS:

| | [rbs-inline] gem | Built into the [rbs] gem |
|---|---|---|
| How it works | Generates `.rbs` files from the comments | Steep reads the comments directly (`check 'file.rb', inline: true`) |
| Status | Prototype, "not actively updated", to be deprecated once merged into rbs | The successor; most features were merged in rbs 4.0 and 4.1 |

This plugin follows the built-in implementation, as specified in [docs/inline.md] of the rbs gem.
That is the implementation Steep uses.

## Struct and Data are not supported yet

The built-in inline syntax has no way to declare the members of a `Struct.new` or `Data.define`:

- The [docs/inline.md] specification does not mention `Struct` or `Data`.
  [docs/data_and_struct.md] says to write the attributes and initializer by hand in a `.rbs` file.
- The rbs inline parser reads `PendingStep = Struct.new(:step, :error)` as a plain constant, and
  `class Box < Struct.new(:width)` as a class without members, with a `NonConstantSuperClassName`
  diagnostic.
- Steep 2.1.0 cannot use the members either. With the rbs-inline member syntax below, it does not
  even know `PendingStep` as a type: `Unknown name for build_instance: PendingStep`.
  [Steep #1196] only makes Steep skip those `#:` member comments.

Support is planned. In [rbs #2061], the rbs maintainer replied that Data/Struct support would come
from merging rbs-inline into the rbs gem. That merge has happened for most features, but not yet
for Struct and Data. The likely syntax is the one rbs-inline supports since version 0.6
([rbs-inline Data/Struct support]):

```ruby
PendingStep = Struct.new(
  :step,           #: Tm::Sts::Step
  :error,          #: String?
  :correlation_id  #: String?
)
```

We do not support this syntax yet, because Steep rejects it. Documented types that the type checker
does not accept would defeat the purpose of the plugin: one type annotation, checked and
documented. Once the rbs gem supports it, the plugin can turn the member types into `@attr` tags.

Until then, either:

- Turn the struct into a plain class with `attr_reader :step #: Type` and a typed `initialize`.
  Inline RBS fully supports that.
- Keep the struct, put its types in a `.rbs` file in `sig/`, and document the members with YARD
  `@attr` tags.

The `# @rbs class Name ... # @rbs end` comment block is not valid in either implementation. The
plugin warns about it as an unsupported annotation.

## Other constructs inline RBS cannot express

The rbs 4.2.0 inline parser ignores the following constructs, or reads them incorrectly. They need
a `.rbs` file.

| Construct | What the rbs inline parser does |
|---|---|
| `Data.define(...)` | Same as `Struct.new`: a plain constant without members |
| `Class.new` / `Module.new` | A plain constant; methods defined in the block are lost |
| Generic classes and modules, `class Box[T]` | Not supported; `# @rbs generic T` is a syntax error |
| Interfaces (`interface _Each`) and type aliases (`type id = Integer`) | No inline syntax |
| Class variables, `@@count` | Ignored |
| `define_method` | Ignored |
| `alias` / `alias_method` | Ignored |
| `def_delegator(s)` (Forwardable) | Ignored |
| `module_function` | The method becomes an instance method only |
| `class << self` | Its methods become instance methods; use `def self.name` instead |
| `private` / `protected` | Ignored; everything is public |
| `include A, B` | Only one module per `include`, `extend` or `prepend` |
| Methods outside a class or module | `TopLevelMethodDefinition` diagnostic |

Most of these only affect type checking. YARD itself still documents methods inside
`class << self`, private methods, aliases and delegators correctly. The plugin can still add the
types of methods that do have an annotation, for example in `class << self`. For `Class.new`,
`define_method` and interfaces there is nothing to annotate.

[rbs]: https://github.com/ruby/rbs
[rbs-inline]: https://github.com/soutaro/rbs-inline
[docs/inline.md]: https://github.com/ruby/rbs/blob/master/docs/inline.md
[docs/data_and_struct.md]: https://github.com/ruby/rbs/blob/master/docs/data_and_struct.md
[rbs #2061]: https://github.com/ruby/rbs/pull/2061
[Steep #1196]: https://github.com/soutaro/steep/pull/1196
[rbs-inline Data/Struct support]: https://github.com/soutaro/rbs-inline/wiki/Data-Struct-support

## Regular RBS files

The types in `.rbs` files are documented too, see the README. YARD's own handling of `.rbs` files
sets these limits:

- `def self?.name: ...` (module function) does not create a YARD object, so it is not documented
  from the `.rbs` file. A Ruby `module_function` method does get the types.
- Interfaces, type aliases and generic parameters have no YARD counterpart and are skipped.
