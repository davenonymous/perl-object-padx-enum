# Object::PadX::Enum

A thin sugar layer over `Object::Pad` that adds two keywords: `enum NAME { ... }`
and `item NAME(...)`. The enum block becomes an `Object::Pad` class with an
auto-injected `$ordinal :reader` field, and each `item` declaration becomes a
class-common accessor returning a singleton instance.

## STRUCTURE

```
perl-object-pad-enum/
├── Makefile.PL                    # ExtUtils::MakeMaker + ExtensionBuilder + XPK::Builder (via INC)
├── MANIFEST
├── MANIFEST.SKIP
├── Changes
├── RELEASING.md                   # maintainer-only; skipped from dist
├── lib/Object/PadX/
│   ├── Enum.pm                    # import(), _begin_enum, _register_item, _finalize_enum
│   └── Enum.xs                    # `enum` and `item` keyword registrations (XPK)
└── t/                             # Test2::V0
    ├── 01-basic.t                 # ordinals, identity
    ├── 02-fields-methods.t        # user fields/methods with :param
    ├── 03-lookups.t               # values, from_ordinal, from_name, empty enum
    ├── 04-errors.t                # item outside enum, duplicates, reserved names
    ├── 05-eval-and-do.t           # eval-string and do-BLOCK contexts
    ├── 06-attributes.t            # enum :isa / :does attribute support
    ├── 07-new-blocked.t           # post-finalize `new` blocking
    ├── 08-enum-inheritance.t      # enum :isa enum semantics
    └── 09-compile-time.t          # BEGIN visibility, constant folding, arg timing
```

## ARCHITECTURE

Two-layer split. XS does keyword parsing only; Perl does all class building
via the documented `Object::Pad::MOP::Class` API.

| Layer | Responsibility                                                           |
|-------|--------------------------------------------------------------------------|
| XS    | Register `enum`/`item` keywords; parse package name + braces + statements |
| XS    | Compile the body (with `_register_item`/`_finalize_enum` call ops) into an anon CV and execute it immediately at parse time |
| Perl  | `_begin_enum`: `begin_class()` + add `$ordinal :reader`                  |
| Perl  | `_register_item`: queue `[name, args, line]` in `%Pending{$class}`       |
| Perl  | `_finalize_enum`: seal, construct singletons, stamp ordinal, install constant accessors |

## EXECUTION TIMELINE

For `enum Colors { item RED(name=>"r"); item BLUE; ... }`:

Everything happens at parse time of the `enum` statement (XS `.build` for
`enum`); the emitted op is a no-op and nothing is left for the enclosing
unit's runtime:

1. **Body parse:**
   - `XPK_PACKAGENAME` reads `Colors`.
   - Call `_begin_enum("Colors")` -> `begin_class` (sets compclassmeta,
     queues UNITCHECK auto-seal CV) -> adds `$ordinal :reader` field.
   - Snapshot + switch `PL_curstash`/`PL_curstname` to `Colors`.
   - `start_subparse` opens an anon CV; `parse_stmtseq(0)` reads the body
     into it; Object::Pad's `field`/`method` keywords fire normally; each
     `item` emits a call op for `_register_item`.
   - Append trailing op `_finalize_enum("Colors")`; `newATTRSUB` closes the
     CV (the same pattern Object::Pad uses for ADJUST blocks).

2. **Immediate execution (`call_sv` on the body CV, still inside `.build`):**
   - Each `item` op evaluates its arg list (at compile time!) and calls
     `_register_item`, queuing `[name, args, line]`.
   - `_finalize_enum` calls `$meta->seal` (instances cannot be constructed
     before seal; the auto-seal queued for UNITCHECK is too late and later
     runs as a tolerated no-op on the already-sealed class), then drains the
     queue: constructs each instance, stamps `$ordinal` and `$_name` via
     `MOP::Field->value($inst) = $v`, installs each item accessor as an
     inlinable constant sub (constant.pm's readonly-scalar-ref-in-stash
     technique), plus `values`/`from_ordinal`/`from_name` as normal subs.
     Then it walks `mro::get_linear_isa` and shadows any ancestor-enum item
     names not redefined locally with croaking stubs, registers the class in
     `%EnumItems`, and finally installs a `new` override that croaks for
     direct calls on the enum class itself but passes through for any other
     invocant (so subclass enums can construct during their own finalize,
     and plain subclasses can still construct normally).

Consequences: singletons exist as soon as the closing brace is parsed (even
for later `BEGIN` blocks in the same file); item args must be compile-time
computable; callers compiled afterwards can constant-fold `Colors::RED()`.

## KEY DESIGN DECISIONS

### Why direct stash manipulation for accessors?

`mop_class_add_method_cv` croaks on a sealed class (Object::Pad's
`class.c:1138`). `_finalize_enum` must seal before constructing singletons,
so MOP `add_method` is structurally unavailable for the singleton accessors.
Item accessors go in as constant-sub proxies (`$stash->{NAME} = \$readonly`,
the constant.pm technique) so that function-style calls constant-fold in
callers; `values`/`from_ordinal`/`from_name` and the `new` override are plain
glob assignments. Both work identically to methods from the caller's
perspective and avoid the seal-timing problem entirely.

### Why is `$ordinal` reader-only, not `:param`?

If `$ordinal` had `:param`, a user writing `item FOO(ordinal => 99)` would
either silently override our injected value or trip `:strict(params)`. Keeping
it reader-only and stamping the value via `MOP::Field->value($inst) = $n`
after construction prevents the leak.

### Why custom `.build` (not `.parse`) for `enum`?

We need to call `_begin_enum` (which calls `begin_class` which sets
compclassmeta) *before* the body is parsed, so that the body's `field` and
`method` keywords see the right compilation state. The body is parsed
manually with `parse_stmtseq(0)` after we've switched the compile-time
package; pieces machinery doesn't expose a "stmtseq between literal braces"
piece type.

### Why is `item` parens-optional?

`XPK_PARENS_OPT(XPK_LISTEXPR)` gives us both `item FOO;` and `item FOO(args);`
for almost no parser cost. The `.i` flag tells `.build` whether args are
present; the `.op` (when present) is the user's list expression.

### Why is `new` blocked post-finalize?

After all singletons are built, `_finalize_enum` captures the original
Object::Pad-generated `new` coderef and replaces `${class}::new` with a
closure that croaks when called with the enum class as the invocant. The
closure delegates to the captured original for any other invocant, so
(a) subclass enums can construct their own singletons during their own
finalize (their construction loop dispatches via MRO into the parent's
override, which sees a non-self invocant and passes through), and (b) plain
`class Sub :isa(EnumParent)` users can still call `Sub->new` normally.
Stash override is the only viable mechanism: by the time singletons exist
the class is sealed, so MOP `add_method` is unavailable. The construction
loop must run *before* the override is installed.

### Why shadow ancestor enum items in child stash?

A child enum inherits fields/methods from its parent but should not inherit
items: parent items have their own ordinals tied to the parent's sequence,
and "lose items" is the documented semantic. After installing its own item
accessors, `_finalize_enum` walks `mro::get_linear_isa` and, for any
ancestor present in `%EnumItems`, installs a croaking stub in the child
stash for each ancestor item name not locally redefined. Name collisions
(child item with the same name as a parent item) are handled naturally by
the child's own accessor going in first; the shadow loop skips any name
already in `%own_names`. `%EnumItems` is the canonical post-finalize
registry: it is populated before the `new` override is installed so that
any descendant enum whose finalize runs later sees the entry.

### Compile-time semantics

The enum body CV is executed during `.build`, so `_finalize_enum` has run by
the time the closing brace has been parsed: singletons are visible to
everything compiled afterwards, including later `BEGIN` blocks of the same
unit (verified in `t/09-compile-time.t`). The flip side is that `item` args
(and any plain statements in the block) execute at compile time and must not
depend on runtime state. Enums are static, fixed value sets by design; args
referencing runtime lexicals see whatever those contain at compile time
(usually `undef`).

## CONVENTIONS

- Module ends with `0x55AA;` (matches Object::Pad / XS::Parse::Keyword style).
- POD uses `=encoding UTF-8` and `=for highlighter language=perl`.
- Tests use `Test2::V0`, 2-digit prefix grouping, `done_testing` at the end.
- XS is in a single file (`lib/Object/PadX/Enum.xs`); no separate `src/*.c`.
- Public surface is whatever appears in the POD of `Enum.pm`; everything in
  the underscored helpers is internal and may change.

## ANTI-PATTERNS

- **DO NOT** add fields, methods, or attributes to the class via the C-level
  Object::Pad API. Use `Object::Pad::MOP::Class` from Perl. The C ABI is the
  most likely thing to break across Object::Pad versions; the Perl MOP is
  documented and stable.
- **DO NOT** try to install singleton accessors via `$meta->add_method` -
  it croaks because the class is already sealed by the time singletons exist.
- **DO NOT** add `:param` to `$ordinal`. See "Why is `$ordinal` reader-only".
- **DO NOT** write `item` args (or other statements inside an enum block)
  that depend on runtime state; the block body executes at compile time.
- **DO NOT** auto-inject `:param` on user fields. Users must write `:param`
  explicitly. Intercepting Object::Pad's `field` keyword would require
  reaching into its internals and is rejected on KISS grounds.
- **DO NOT** use names `values`, `from_ordinal`, `from_name`, `ordinal`,
  `name`, `new`, `BUILD`, `DOES`, or `META` as `item` names; they are reserved
  by either us or Object::Pad.

## RELATED PUBLIC APIs

| Need                                | Where                                       |
|-------------------------------------|---------------------------------------------|
| Register a keyword plugin           | `XSParseKeyword.h` (`register_xs_parse_keyword`) |
| Begin a class at compile time       | `Object::Pad::MOP::Class->begin_class`       |
| Add a field with reader/param       | `$meta->add_field('$name', reader=>'x', ...)` |
| Seal a class before UNITCHECK       | `$meta->seal`                               |
| Mutate a field value on an instance | `$meta->get_field('$x')->value($inst) = $v` |
| Probe-then-consume a single char    | local `lex_consume_unichar` shim (Enum.xs)  |
