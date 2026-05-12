use v5.22;
use warnings;

use Module::Build;
use XS::Parse::Keyword::Builder;
use Object::Pad::ExtensionBuilder;

my $build = Module::Build->new(
   module_name => 'Object::PadX::Enum',
   dist_abstract => 'syntactic sugar for enum-like singleton-bearing Object::Pad classes',
   license => 'perl',
   author => [ 'Dave' ],

   configure_requires => {
      'Module::Build'                 => 0,
      'XS::Parse::Keyword::Builder'   => '0.48',
      'Object::Pad::ExtensionBuilder' => 0,
   },

   requires => {
      'perl'               => '5.022',
      'XS::Parse::Keyword' => '0.48',
      'Object::Pad'        => '0.825',
   },

   test_requires => {
      'Test2::V0' => 0,
   },
);

XS::Parse::Keyword::Builder->extend_module_build($build);
Object::Pad::ExtensionBuilder->extend_module_build($build);

$build->create_build_script;
