#!perl
use v5.22;
use warnings;

use Test2::V0;

use Object::Pad::Enum;

# Compile-time error: val outside enum.
{
   my $ok = eval q{
      use Object::Pad::Enum;
      val NOPE;
      1;
   };
   ok( !$ok, 'val outside enum is a compile error' );
   like( $@, qr/val/, 'error message mentions val' );
}

# Runtime error: duplicate val name.
{
   my $ok = eval q{
      use Object::Pad::Enum;
      enum Dup {
         val SAME;
         val SAME;
      }
      1;
   };
   ok( !$ok, 'duplicate val names croak' );
   like( $@, qr/Duplicate val 'SAME'/, 'duplicate error mentions name' );
}

# Runtime error: reserved val name.
{
   my $ok = eval q{
      use Object::Pad::Enum;
      enum Reserved {
         val values;
      }
      1;
   };
   ok( !$ok, 'reserved name "values" rejected' );
   like( $@, qr/reserved/, 'reserved error message' );
}

# Runtime error: reserved val name "name".
{
   my $ok = eval q{
      use Object::Pad::Enum;
      enum ReservedName {
         val name;
      }
      1;
   };
   ok( !$ok, 'reserved name "name" rejected' );
   like( $@, qr/reserved/, 'reserved error message for name' );
}

# Compile-time error: val outside enum, without `use` in eval (hint key gates it).
{
   my $ok = eval q{
      val LOOSE;
      1;
   };
   ok( !$ok, 'val with no hint key is a syntax error' );
}

done_testing;
