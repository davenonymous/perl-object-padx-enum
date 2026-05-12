package Object::Pad::Enum 0.01;

use v5.22;
use warnings;

use Carp;
use Object::Pad 0.825 ();
use Object::Pad::MOP::Class qw( :experimental(mop) );

# Loaded for its XS keyword registrations
require XSLoader;
XSLoader::load( __PACKAGE__, our $VERSION );

=encoding UTF-8

=for highlighter language=perl

=head1 NAME

C<Object::Pad::Enum> - syntactic sugar for enum-like singleton-bearing C<Object::Pad> classes

=head1 SYNOPSIS

   use Object::Pad::Enum;

   enum Colors {
      val RED  ( label => 'red',  hex => '#FF0000' );
      val BLUE ( label => 'blue', hex => '#0000FF' );

      field $label :param :reader;
      field $hex   :param :reader;

      method uc_label { return uc $label; }
   }

   say Colors->RED->ordinal;     # 0
   say Colors->RED->name;        # RED
   say Colors->RED->label;       # red
   say Colors->BLUE->uc_name;    # BLUE
   say $_->name for Colors->values;

=head1 DESCRIPTION

C<Object::Pad::Enum> adds two keywords on top of L<Object::Pad>:

=over 4

=item * C<enum NAME { ... }>

Declares a class (using L<Object::Pad>'s C<class> machinery) and auto-injects
C<$ordinal :reader> and C<name :reader> fields. The C<name> reader returns the
identifier under which the singleton was declared (e.g. C<"RED">). Inside the
block, all normal C<Object::Pad> constructs (C<field>, C<method>, C<ADJUST>,
...) are available, plus the C<val> keyword.

=item * C<val NAME ( ARGS );>

Declares a named singleton instance of the enclosing C<enum>. C<ARGS> is the
key/value list passed to the auto-generated constructor; the parentheses (and
the arg list) are optional, so C<val FOO;> is equivalent to C<val FOO();>.

=back

After the C<enum> block closes, the following class-level methods are
installed on the enum class for each declared singleton C<NAME>:

   $singleton = ClassName->NAME;          # the named singleton
   @all       = ClassName->values;        # all singletons in declaration order
   $byord     = ClassName->from_ordinal(0);
   $byname    = ClassName->from_name("RED");

=head1 CAVEATS

=over 4

=item *

User C<field>s require explicit C<:param> if you intend to set them via C<val>
args. C<Object::Pad::Enum> does I<not> inject C<:param> automatically.

=item *

Singletons are constructed at the runtime of the compilation unit that
contains the C<enum> declaration, after that unit's C<UNITCHECK> phase. They
are therefore not visible from earlier C<BEGIN>/C<UNITCHECK> blocks of the
same unit. Normal runtime code (including code inside C<do BLOCK> and
C<eval "STRING"> blocks executed during main runtime) sees them as expected.

=item *

C<enum>-level attributes (C<:isa>, C<:does>, C<:strict>, etc.) are not
supported. If you need them, declare a plain C<class> instead.

=item *

The names C<values>, C<from_ordinal>, C<from_name>, C<ordinal> and C<name> are
reserved and must not be used as C<val> names.

=back

=cut

# Per-class state captured during compilation.
# $Pending{$class} = { meta => $meta, vals => [ [ $name, \@args, $line ], ... ], seen => { $name => 1 } }
my %Pending;

my %RESERVED_VAL_NAMES = map { $_ => 1 } qw(
   values from_ordinal from_name ordinal name
   new BUILD DOES META
);

sub import {
   my $class  = shift;
   my $caller = caller;

   $^H{ 'Object::Pad::Enum/enum' } = 1;
   $^H{ 'Object::Pad::Enum/val'  } = 1;

   Object::Pad->import_into( $caller );
}

# Called by XS at compile-time when `enum NAME {` is encountered.
sub _begin_enum {
   my ( $name ) = @_;

   exists $Pending{ $name }
      and croak "Cannot declare enum '$name'; already being defined";

   my $meta = Object::Pad::MOP::Class->begin_class( $name );

   # $ordinal and $_name are reader-only (not :param) so user val args cannot
   # override them; both are stamped after construction in _finalize_enum.
   $meta->add_field( '$ordinal', reader => 'ordinal' );
   $meta->add_field( '$_name',   reader => 'name'    );

   $Pending{ $name } = { meta => $meta, vals => [], seen => {} };

   return;
}

# Called at runtime, in source order, for each `val NAME(args)` statement.
sub _register_val {
   my ( $class, $name, $line, @args ) = @_;

   my $entry = $Pending{ $class }
      or croak "Internal error: val '$name' for unknown enum '$class' at line $line";

   $entry->{ seen }{ $name }
      and croak "Duplicate val '$name' in enum '$class' at line $line";

   $RESERVED_VAL_NAMES{ $name }
      and croak "val name '$name' is reserved in enum '$class' at line $line";

   push @{ $entry->{ vals } }, [ $name, \@args, $line ];
   $entry->{ seen }{ $name } = 1;

   return;
}

# Called at runtime, once, after all val statements for the enum have run.
sub _finalize_enum {
   my ( $class ) = @_;

   my $entry = delete $Pending{ $class }
      or croak "Internal error: _finalize_enum on unknown enum '$class'";

   my $meta       = $entry->{ meta };
   my $ord_field  = $meta->get_field( '$ordinal' );
   my $name_field = $meta->get_field( '$_name'   );
   my @ordered;

   my $n = 0;
   for my $val ( @{ $entry->{ vals } } ) {
      my ( $name, $args, $line ) = @$val;

      my $instance = eval { $class->new( @$args ) };
      $@ and croak "Failed to construct enum value '$name' of '$class' at line $line: $@";

      # Stamp the ordinal and name after construction so they aren't user-facing :params.
      $ord_field->value(  $instance ) = $n;
      $name_field->value( $instance ) = $name;

      push @ordered, [ $name, $instance ];
      $n++;
   }

   no strict 'refs';
   no warnings 'redefine';

   for my $pair ( @ordered ) {
      my ( $name, $instance ) = @$pair;
      *{ "${class}::${name}" } = sub { $instance };
   }

   *{ "${class}::values" } = sub {
      return map { $_->[1] } @ordered;
   };

   *{ "${class}::from_ordinal" } = sub {
      my ( undef, $idx ) = @_;
      defined $idx                  or return undef;
      $idx >= 0 && $idx < @ordered  or return undef;
      return $ordered[ $idx ][ 1 ];
   };

   *{ "${class}::from_name" } = sub {
      my ( undef, $want ) = @_;
      defined $want or return undef;
      for my $pair ( @ordered ) {
         return $pair->[1] if $pair->[0] eq $want;
      }
      return undef;
   };

   return;
}

0x55AA;
