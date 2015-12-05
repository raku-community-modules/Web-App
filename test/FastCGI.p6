#!/usr/bin/env perl6

use lib 'lib';

use FastCGI;
use Web::App;

my $scgi = FastCGI.new(:port(9119));
my $app = Web::App.new($scgi);

my $handler = sub ($context) {
  $context.set-status(200);
  $context.content-type('text/plain');
  my $name = $context.get(:default<World>, 'name');
  $context.send("Hello $name\n");
  $context.send("How are you today?\n");
}

$app.run: $handler;

