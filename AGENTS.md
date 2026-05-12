# Object::PadX::Enum

A thin sugar layer over `Object::Pad` that adds two keywords: `enum NAME { ... }`
and `item NAME(...)`. The enum block becomes an `Object::Pad` class with an
auto-injected `$ordinal :reader` field, and each `item` declaration becomes a
class-common accessor returning a singleton instance.

## STRUCTURE

```
perl-object-pad-enum/
├── Build.PL                       # Module::Build + ExtensionBuilder + XPK::Builder
├── Changes
├── MANIFEST
├── lib/Object/Pad/
│   ├── Enum.pm                    # import(), _begin_enum, _register_item, _finalize_enum
│   └── Enum.xs                    # `enum` and `item` keyword registrations (XPK)
└── t/                             # Test2::V0
    ├── 01-basic.t                 # ordinals, identity
    ├── 02-fields-methods.t        # user fields/methods with :param
    ├── 03-lookups.t               # values, from_ordinal, from_name, empty enum
    ├── 04-errors.t                # item outside enum, duplicates, reserved names
    ├── 05-eval-and-do.t           # eval-string and do-BLOCK contexts
    └── 06-attributes.t            # enum :isa / :does attribute support
```

## ARCHITECTURE

Two-layer split. XS does keyword parsing only; Perl does all class building
via the documented `Object::Pad::MOP::Class` API.

| Layer | Responsibility                                                           |
|-------|--------------------------------------------------------------------------|
| XS    | Register `enum`/`item` keywords; parse package name + braces + statements |
| XS    | Emit runtime ops calling Perl helpers (`_register_item`, `_finalize_enum`) |
| Perl  | `_begin_enum`: `begin_class()` + add `$ordinal :reader`                  |
| Perl  | `_register_item`: queue `[name, args, line]` in `%Pending{$class}`       |
| Perl  | `_finalize_enum`: construct singletons, stamp ordinal, install accessors |

## EXECUTION TIMELINE

For `enum Colors { item RED(name=>"r"); item BLUE; ... }`:

1. **Parse time (XS `.build` for `enum`):**
   - `XPK_PACKAGENAME` reads `Colors`.
   - Call `_begin_enum("Colors")` -> `begin_class` (sets compclassmeta,
     queues UNITCHECK auto-seal CV) -> adds `$ordinal :reader` field.
   - Snapshot + switch `PL_curstash`/`PL_curstname` to `Colors`.
   - `parse_stmtseq(0)` reads the body; Object::Pad's `field`/`method`
     keywords fire normally; each `item` emits a runtime call op.
   - Emit trailing op: `_finalize_enum("Colors")`.

2. **UNITCHECK phase of the enclosing compilation unit:**
   - `begin_class`'s queued seal CV fires; class is sealed.

3. **Runtime of that unit (in source order):**
   - Each `item`'s runtime op evaluates its arg list and calls `_register_item`,
     queuing `[name, args, line]`.
   - `_finalize_enum` drains the queue: constructs each instance, stamps
     `$ordinal` and `$_name` via `MOP::Field->value($inst) = $v`, installs
     accessor subs via direct stash manipulation, plus
     `values`/`from_ordinal`/`from_name`. Then it walks `mro::get_linear_isa`
     and shadows any ancestor-enum item names not redefined locally with
     croaking stubs, registers the class in `%EnumItems`, and finally
     installs a `new` override that croaks for direct calls on the enum
     class itself but passes through for any other invocant (so subclass
     enums can construct during their own finalize, and plain subclasses
     can still construct normally).

## KEY DESIGN DECISIONS

### Why direct stash manipulation for accessors?

`mop_class_add_method_cv` croaks on a sealed class (Object::Pad's
`class.c:1138`). Since `begin_class`'s auto-seal fires at UNITCHECK and
singletons can only be constructed *after* seal, MOP `add_method` is
structurally unavailable for the singleton accessors. Plain
`*{"${pkg}::NAME"} = sub { $instance }` works identically from the caller's
perspective and avoids the seal-timing problem entirely.

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

### Singleton timing caveat

Singletons live in the package stash only after `_finalize_enum` runs, which
is during the *runtime* of the unit containing the `enum` block (after that
unit's UNITCHECK seal). They are therefore not visible from earlier
`BEGIN`/`UNITCHECK` blocks of the same unit. Normal runtime, including code
inside same-unit `do { ... }` and `eval "STRING"`, sees them as expected
(verified in `t/05-eval-and-do.t`).

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
- **DO NOT** assume singletons are visible during compilation-time phasers
  of the same unit (BEGIN, UNITCHECK before the seal). The caveat is real
  and documented.
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
| Mutate a field value on an instance | `$meta->get_field('$x')->value($inst) = $v` |
| Probe-then-consume a single char    | local `lex_consume_unichar` shim (Enum.xs)  |
