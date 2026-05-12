#!perl
# Planet: the eight planets of the solar system. Each carries mass and radius;
# surface_gravity derives g from Newton's law of gravitation.

use v5.22;
use warnings;
use Object::PadX::Enum;

my $G = 6.67430e-11;   # m^3 kg^-1 s^-2

enum Planet {
   item MERCURY ( mass_kg => 3.303e+23, radius_m => 2.4397e6 );
   item VENUS   ( mass_kg => 4.869e+24, radius_m => 6.0518e6 );
   item EARTH   ( mass_kg => 5.976e+24, radius_m => 6.37814e6 );
   item MARS    ( mass_kg => 6.421e+23, radius_m => 3.3972e6 );
   item JUPITER ( mass_kg => 1.9e+27,   radius_m => 7.1492e7 );
   item SATURN  ( mass_kg => 5.688e+26, radius_m => 6.0268e7 );
   item URANUS  ( mass_kg => 8.686e+25, radius_m => 2.5559e7 );
   item NEPTUNE ( mass_kg => 1.024e+26, radius_m => 2.4746e7 );

   field $mass_kg  :param :reader;
   field $radius_m :param :reader;

   method surface_gravity { return $G * $mass_kg / ( $radius_m ** 2 ) }
}

printf "%-8s %12s %12s %10s\n", 'NAME', 'mass (kg)', 'radius (m)', 'g (m/s^2)';
for my $planet ( Planet->values ) {
   printf "%-8s %12.3e %12.3e %10.3f\n",
      $planet->name, $planet->mass_kg, $planet->radius_m,
      $planet->surface_gravity;
}

my $weight_n = 80 * Planet->EARTH->surface_gravity;
printf "\nan 80 kg human weighs %.1f N on Earth and %.1f N on Mars\n",
   $weight_n, 80 * Planet->MARS->surface_gravity;
