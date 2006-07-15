#!perl

use strict;
use warnings;

use lib 'lib';
use lib 't/lib';
use Test::More 'no_plan';

use TWMO;
use Test::WWW::Mechanize::Object;

my $mech = Test::WWW::Mechanize::Object->new(
  handler => TWMO->new,
);

isa_ok $mech, 'Test::WWW::Mechanize::Object';

my $i;
my $HOST = "http://localhost";
TESTS: {
  $mech->get_ok($HOST || "/", "get no pie");

  $mech->content_like(qr/to nowhere/, "got nowhere");
  $mech->content_like(qr/a void pie/, "got a void pie");
  
  $mech->get_ok(
    "$HOST/kitchen?pie=cherry", 
    "get cherry pie"
  );
  
  $mech->content_like(qr{to /kitchen},  "got to the kitchen");
  $mech->content_like(qr{a cherry pie}, "got a cherry pie");
  
  $mech->get_ok(
    "$HOST/windowsill?pie=random",
    "get random pie (redirect)"
  );
  
  $mech->content_like(qr{to /windowsill}, "path preserved");
  $mech->content_unlike(qr{a random pie}, "no longer random pie");
  $mech->content_unlike(qr{a void pie},   "not a void pie either");

  unless ($i++) {
    # switch to remote-possible mode and try them all again
    $ENV{TWMO_SERVER} = 'http://myserver.com/myurl';
    $HOST = "";
    $mech->{handler} = TWMO::Remote->new;
    redo TESTS;
  }
}
