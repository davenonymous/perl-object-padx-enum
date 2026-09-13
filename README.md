# NAME

`Object::PadX::Enum` - syntactic sugar for enum-like singleton-bearing `Object::Pad` classes

# SYNOPSIS

```perl
use Object::PadX::Enum;

enum Raptor {
   item VELOCIRAPTOR   ( max_speed_kmh => 60, max_weight_kg =>  15, max_height_cm =>  50 );
   item DEINONYCHUS    ( max_speed_kmh => 50, max_weight_kg =>  80, max_height_cm =>  87 );
   item UTAHRAPTOR     ( max_speed_kmh => 35, max_weight_kg => 500, max_height_cm => 150 );
   item MICRORAPTOR    ( max_speed_kmh => 40, max_weight_kg =>   1, max_height_cm =>  30 );
   item DROMAEOSAURUS  ( max_speed_kmh => 60, max_weight_kg =>  15, max_height_cm =>  50 );

   field $max_speed_kmh  :param :reader;
   field $max_weight_kg  :param :reader;
   field $max_height_cm  :param :reader;

   method speed_per_kg { return $max_speed_kmh / $max_weight_kg }
   method speed_per_cm { return $max_speed_kmh / $max_height_cm }

   method fastest :common {
      my ( $top ) = sort { $b->max_speed_kmh <=> $a->max_speed_kmh } $class->values;
      return $top;
   }
}

say Raptor->VELOCIRAPTOR->max_speed_kmh;  # 60
say Raptor->DEINONYCHUS->speed_per_kg;    # 0.625
say Raptor->from_ordinal(2)->name;        # UTAHRAPTOR
say Raptor->from_name("MICRORAPTOR")->speed_per_cm; # 1.33333333333333
say 'Fastest in absolute terms: ', Raptor->fastest->name; # VELOCIRAPTOR or DROMAEOSAURUS (tie)
```

# DESCRIPTION

`Object::PadX::Enum` adds two keywords on top of [Object::Pad](https://metacpan.org/pod/Object%3A%3APad):

- `enum NAME ATTRS? { ... }`

    Declares a class (using [Object::Pad](https://metacpan.org/pod/Object%3A%3APad)'s `class` machinery) and auto-injects
    `$ordinal :reader` and `name :reader` fields. The `name` reader returns the
    identifier under which the singleton was declared (e.g. `"RED"`). Inside the
    block, all normal `Object::Pad` constructs (`field`, `method`, `ADJUST`,
    ...) are available, plus the `item` keyword.

    The entire block body is executed while it is being compiled, BEGIN-block
    style; see ["COMPILE-TIME SEMANTICS"](#compile-time-semantics).

    The following class-level attributes are accepted:

    - `:isa(CLASS)`, `:isa(CLASS VERSION)`
    - `:extends(CLASS)`, `:extends(CLASS VERSION)`

        Declares a superclass; equivalent to [Object::Pad](https://metacpan.org/pod/Object%3A%3APad)'s `:isa`. The package is
        loaded automatically. If a VERSION is given, `CLASS->VERSION(VERSION)` is
        called to enforce it.

        An `enum` may inherit from another `enum`. Fields, methods, roles and
        `ADJUST` phasers from the parent are inherited normally. The parent's
        **items** are _not_ inherited: the child has its own ordinal-zero-based item
        sequence, and accessing a parent item name on the child raises an error. The
        child's `values`, `from_ordinal` and `from_name` see only the child's
        items. A parent enum must be declared before a child enum that inherits from
        it; since enums are finalized while they are compiled, normal source ordering
        and `use` ordering satisfies this.

    - `:does(ROLE)`, `:does(ROLE VERSION)`

        Composes a role into the enum class. May be repeated for multiple roles. The
        role package is loaded automatically.

    The class attributes `:abstract`, `:strict`, `:repr` and `:lexical_new`
    are not supported. `:abstract` is semantically incompatible with `item`
    (singletons cannot be constructed for an abstract class); the others have no
    public [Object::Pad::MOP::Class](https://metacpan.org/pod/Object%3A%3APad%3A%3AMOP%3A%3AClass) entry point and would require reaching into
    private Object::Pad internals.

- `item NAME ( ARGS );`

    Declares a named singleton instance of the enclosing `enum`. `ARGS` is the
    key/value list passed to the auto-generated constructor; the parentheses (and
    the arg list) are optional, so `item FOO;` is equivalent to `item FOO();`.

    `ARGS` is evaluated at compile time and therefore must not depend on runtime
    state; see ["COMPILE-TIME SEMANTICS"](#compile-time-semantics).

After the `enum` block closes, the following class-level methods are
installed on the enum class for each declared singleton `NAME`:

```perl
$singleton = ClassName->NAME;          # the named singleton
@all       = ClassName->values;        # all singletons in declaration order
$byord     = ClassName->from_ordinal(0);
$byname    = ClassName->from_name("RED");
```

The per-item accessors are installed as inlinable constant subs (of the kind
created by [constant](https://metacpan.org/pod/constant)), so a function-style call such as
`ClassName::NAME()` is folded to a constant at the caller's compile
time. Method-call syntax `ClassName->NAME` dispatches through the same
sub and returns the same singleton.

Direct construction via `ClassName->new(...)` is blocked after the
`enum` block closes; the only ways to obtain a singleton are the per-item
accessor, `from_name`, and `from_ordinal`. Subclasses (whether plain
`class` or another `enum`) may still call `new` on themselves; the block
applies only to direct invocation on the enum class itself.

# COMPILE-TIME SEMANTICS

Enums are static, fixed sets of values, and the implementation treats them
that way: the whole `enum` block body is executed while it is being
compiled, much like a `BEGIN` block. In particular:

- The singletons are constructed, and all accessors installed, as soon as the
closing brace of the `enum` block has been parsed. They are visible from any
code compiled afterwards, including `BEGIN` blocks later in the same file.
- `item` args are ordinary Perl expressions, but they are evaluated at compile
time. An expression referencing runtime state (for example a lexical assigned
during normal runtime) sees the value that variable has at compile time,
usually `undef`. Use only compile-time-computable expressions in `item`
args.
- Any other plain statements written inside the block also run at compile time.

Because construction happens at compile time, values derived from item args
can be precomputed once per singleton instead of recomputed on every call.
Assign them to a field in an `ADJUST` block:

```perl
enum Raptor {
   item VELOCIRAPTOR ( max_speed_kmh => 60, max_weight_kg => 15 );

   field $max_speed_kmh :param :reader;
   field $max_weight_kg :param :reader;

   field $speed_per_kg :reader;
   ADJUST { $speed_per_kg = $max_speed_kmh / $max_weight_kg }
}
```

`Raptor->VELOCIRAPTOR->speed_per_kg` then returns a value computed once,
at compile time, through a plain generated reader instead of a computing
method.

# CAVEATS

- User `field`s require explicit `:param` if you intend to set them via
`item` args. `Object::PadX::Enum` does _not_ inject `:param` automatically.
- The `enum` block body executes at compile time, so `item` args (and any
other statements inside the block) must not depend on runtime state. See
["COMPILE-TIME SEMANTICS"](#compile-time-semantics).
- `enum`-level `:abstract`, `:strict`, `:repr` and `:lexical_new` are not
supported. See the description of the `enum` keyword above for the rationale;
`:isa` and `:does` _are_ supported.
- The names `values`, `from_ordinal`, `from_name`, `ordinal` and `name` are
reserved and must not be used as `item` names.
