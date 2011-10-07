#!/usr/bin/env perl6

BEGIN { @*INC.push: './lib'; }

use SCGI;
use WWW::App;

my $scgi = SCGI.new(:port(8118), :PSGI, :!strict, :debug);
my $app = WWW::App.new($scgi);

my $handler = sub ($context) {
  $context.set-status(200);
  $context.content-type('text/plain');
  my $name = $context.get(:default<World>, 'name');
  $context.send("Hello $name");
  $context.send("How are you today?");
}

$app.run: $handler;

