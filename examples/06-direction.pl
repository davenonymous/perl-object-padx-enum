#!perl
# Direction: the four cardinal compass points with unit-vector components and
# rotation helpers built on ordinal arithmetic.

use v5.22;
use warnings;
use Object::Pad::Enum;

enum Direction {
   item NORTH ( dx =>  0, dy =>  1 );
   item EAST  ( dx =>  1, dy =>  0 );
   item SOUTH ( dx =>  0, dy => -1 );
   item WEST  ( dx => -1, dy =>  0 );

   field $dx :param :reader;
   field $dy :param :reader;

   method turn_right { return __CLASS__->from_ordinal( ( $self->ordinal + 1 ) % 4 ) }
   method turn_left  { return __CLASS__->from_ordinal( ( $self->ordinal + 3 ) % 4 ) }
   method opposite   { return __CLASS__->from_ordinal( ( $self->ordinal + 2 ) % 4 ) }

   method step ($x, $y) { return ( $x + $dx, $y + $dy ) }
}

my @moves   = ( 'forward', 'right', 'forward', 'forward', 'left', 'forward' );
my $heading = Direction->NORTH;
my ( $x, $y ) = ( 0, 0 );

printf "start    facing %-5s at (%d, %d)\n", $heading->name, $x, $y;
for my $move ( @moves ) {
   if    ( $move eq 'right' )   { $heading = $heading->turn_right }
   elsif ( $move eq 'left'  )   { $heading = $heading->turn_left  }
   elsif ( $move eq 'forward' ) { ( $x, $y ) = $heading->step( $x, $y ) }
   printf "%-8s facing %-5s at (%d, %d)\n", $move, $heading->name, $x, $y;
}

say '';
say 'opposite of EAST is ', Direction->EAST->opposite->name;
