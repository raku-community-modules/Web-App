#!/usr/bin/env perl6

BEGIN { @*INC.push: './lib'; }

use FastCGI;
use WWW::App;

my $scgi = FastCGI.new(:port(9119));
my $app = WWW::App.new($scgi);

my $handler = sub ($context) {
  $context.set-status(200);
  $context.content-type('text/plain');
  my $name = $context.get(:default<World>, 'name');
  $context.send("Hello $name\n");
  $context.send("How are you today?\n");
}

$app.run: $handler;

