#!perl
use v5.22;
use warnings;

use Test2::V0;

use Object::Pad::Enum;

enum Colors {
   val RED  ( name => 'red',  hex => '#FF0000' );
   val BLUE ( name => 'blue', hex => '#0000FF' );

   field $name :param :reader;
   field $hex  :param :reader;

   method uc_name() { return uc $name; }
}

is( Colors->RED->name,    'red',     'RED->name reader' );
is( Colors->RED->hex,     '#FF0000', 'RED->hex reader' );
is( Colors->RED->uc_name, 'RED',     'RED->uc_name method' );
is( Colors->RED->ordinal, 0,         'RED ordinal' );

is( Colors->BLUE->name,    'blue',     'BLUE->name reader' );
is( Colors->BLUE->hex,     '#0000FF',  'BLUE->hex reader' );
is( Colors->BLUE->uc_name, 'BLUE',     'BLUE->uc_name method' );
is( Colors->BLUE->ordinal, 1,          'BLUE ordinal' );

done_testing;
