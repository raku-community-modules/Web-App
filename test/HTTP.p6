#!/usr/bin/env perl6

BEGIN { @*INC.push: './lib'; }

use HTTP::Easy::PSGI;
use Web::App;

my $psgi = HTTP::Easy::PSGI.new(:port(8080));
my $app = Web::App.new($psgi);

my $handler = sub ($context) {
  $context.set-status(200);
  $context.content-type('text/plain');
  my $name = $context.get(:default<World>, 'name');
  $context.send("Hello $name\n");
  $context.send("How are you today?\n");
}

$app.run: $handler;

