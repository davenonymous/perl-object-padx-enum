#!perl
# CardSuit: the four playing-card suits with a single-letter symbol and a
# color, plus an is_red predicate.

use v5.22;
use warnings;
use Object::PadX::Enum;

enum CardSuit {
   item HEARTS   ( symbol => 'H', color => 'red'   );
   item DIAMONDS ( symbol => 'D', color => 'red'   );
   item CLUBS    ( symbol => 'C', color => 'black' );
   item SPADES   ( symbol => 'S', color => 'black' );

   field $symbol :param :reader;
   field $color  :param :reader;

   method is_red { return $color eq 'red' }
}

for my $suit ( CardSuit->values ) {
   printf "%s  %-8s  %-5s  %s\n",
      $suit->symbol, $suit->name, $suit->color,
      $suit->is_red ? '(red)' : '(black)';
}

say '';
say 'parsed from symbol D: ',
   ( grep { $_->symbol eq 'D' } CardSuit->values )[0]->name;
