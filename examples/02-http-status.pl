#!perl
# HttpStatus: a handful of well-known status codes with category predicates
# and a class-level get($code) lookup that scans values().

use v5.22;
use warnings;
use Object::Pad::Enum;

enum HttpStatus {
   item OK                    ( code => 200, reason => 'OK' );
   item CREATED               ( code => 201, reason => 'Created' );
   item NO_CONTENT            ( code => 204, reason => 'No Content' );
   item MOVED_PERMANENTLY     ( code => 301, reason => 'Moved Permanently' );
   item FOUND                 ( code => 302, reason => 'Found' );
   item BAD_REQUEST           ( code => 400, reason => 'Bad Request' );
   item UNAUTHORIZED          ( code => 401, reason => 'Unauthorized' );
   item NOT_FOUND             ( code => 404, reason => 'Not Found' );
   item IM_A_TEAPOT           ( code => 418, reason => "I'm a teapot" );
   item INTERNAL_SERVER_ERROR ( code => 500, reason => 'Internal Server Error' );
   item SERVICE_UNAVAILABLE   ( code => 503, reason => 'Service Unavailable' );

   field $code   :param :reader;
   field $reason :param :reader;

   method is_success      { return $code >= 200 && $code < 300 }
   method is_redirect     { return $code >= 300 && $code < 400 }
   method is_client_error { return $code >= 400 && $code < 500 }
   method is_server_error { return $code >= 500 && $code < 600 }

   method get :common ($wanted) {
      for my $status ( $class->values ) {
         return $status if $status->code == $wanted;
      }
      return undef;
   }
}

for my $code ( 200, 302, 404, 418, 503, 999 ) {
   my $status = HttpStatus->get( $code );
   if ( !$status ) {
      printf "%3d -> (unknown)\n", $code;
      next;
   }
   printf "%3d %s (%s)\n",
      $status->code, $status->reason, $status->name;
}

say '';
say 'teapot is a client error? ',
   HttpStatus->IM_A_TEAPOT->is_client_error ? 'yes' : 'no';
