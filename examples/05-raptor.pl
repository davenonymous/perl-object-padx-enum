#!perl
# Raptor: dromaeosaurids, as on the cover of every Perl book. Each one carries
# estimated speed, weight and hip height, plus a few derived ratios.

use v5.22;
use warnings;
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

printf "%-15s %7s %7s %7s %12s\n", 'NAME', 'km/h', 'kg', 'cm', 'km/h per kg';
for my $r ( sort { $b->speed_per_kg <=> $a->speed_per_kg } Raptor->values ) {
   printf "%-15s %7d %7d %7d %12.2f\n",
      $r->name, $r->max_speed_kmh, $r->max_weight_kg,
      $r->max_height_cm, $r->speed_per_kg;
}

say '';
say 'fastest in absolute terms: ', Raptor->fastest->name;
