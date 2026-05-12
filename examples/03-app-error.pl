#!perl
# AppError: a small catalogue of application errors. Each singleton carries a
# numeric code and a human message, and knows how to throw itself.

use v5.22;
use warnings;
use feature 'signatures';
no warnings 'experimental::signatures';
use Carp ();
use Object::Pad::Enum;

enum AppError {
   item NOT_FOUND    ( code => 1404, message => 'Resource not found'    );
   item BAD_INPUT    ( code => 1400, message => 'Bad input'             );
   item UNAUTHORIZED ( code => 1401, message => 'Authentication required' );
   item CONFLICT     ( code => 1409, message => 'Conflict with current state' );
   item INTERNAL     ( code => 1500, message => 'Internal error'        );

   field $code    :param :reader;
   field $message :param :reader;

   method throw ($detail = undef) {
      my $suffix = defined $detail ? ": $detail" : '';
      Carp::croak sprintf '[%s/%d] %s%s',
         $self->name, $code, $message, $suffix;
   }
}

sub find_user ($id) {
   AppError->BAD_INPUT->throw( 'id must be positive' ) if $id <= 0;
   AppError->NOT_FOUND->throw( "user id=$id" )         if $id != 42;
   return { id => $id, name => 'Ada' };
}

for my $id ( 42, 0, 7 ) {
   my $user = eval { find_user( $id ) };
   if ( $@ ) {
      chomp( my $err = $@ );
      say "id=$id -> error: $err";
      next;
   }
   say "id=$id -> ok: $user->{name}";
}
