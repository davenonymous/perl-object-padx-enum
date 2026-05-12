#!perl
# OnionState: a linear state machine tracking a chef dicing an onion.
# advance() walks forward and stops at PLATED.

use v5.22;
use warnings;
use Object::PadX::Enum;

enum OnionState {
   item PEELING ( description => 'removing the papery skin'   );
   item HALVING ( description => 'splitting the onion in two' );
   item SLICING ( description => 'cutting parallel slices'    );
   item DICING  ( description => 'crosscutting into cubes'    );
   item PLATED  ( description => 'transferred to the board'   );

   field $description :param :reader;

   method advance {
      return __CLASS__->from_ordinal( $self->ordinal + 1 ) // $self;
   }

   method is_done { return $self->name eq 'PLATED' }
}

my $state = OnionState->PEELING;
while ( !$state->is_done ) {
   printf "step %d: %-7s -- %s\n",
      $state->ordinal, $state->name, $state->description;
   $state = $state->advance;
}
printf "step %d: %-7s -- %s\n",
   $state->ordinal, $state->name, $state->description;
