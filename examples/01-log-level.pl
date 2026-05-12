#!perl
# LogLevel: classic severity ladder with numeric priorities and a comparison
# helper, plus a tiny log() that filters by a configured threshold.

use v5.22;
use warnings;
use Object::Pad::Enum;

enum LogLevel {
   item TRACE ( priority => 10, label => 'TRACE' );
   item DEBUG ( priority => 20, label => 'DEBUG' );
   item INFO  ( priority => 30, label => 'INFO ' );
   item WARN  ( priority => 40, label => 'WARN ' );
   item ERROR ( priority => 50, label => 'ERROR' );
   item FATAL ( priority => 60, label => 'FATAL' );

   field $priority :param :reader;
   field $label    :param :reader;

   method gte ($other) { return $priority >= $other->priority }

   method log ($threshold, $message) {
      return unless $self->gte( $threshold );
      printf "[%s] %s\n", $label, $message;
   }
}

my $threshold = LogLevel->INFO;

LogLevel->DEBUG->log( $threshold, 'connecting to database' );
LogLevel->INFO ->log( $threshold, 'server listening on :8080' );
LogLevel->WARN ->log( $threshold, 'slow query: 1.4s' );
LogLevel->ERROR->log( $threshold, 'upstream returned 502' );

say '';
say "all levels in order: ", join ' < ', map { $_->name } LogLevel->values;
