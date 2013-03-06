#!/usr/bin/env perl6

BEGIN { @*INC.push: './lib'; }

use SCGI;
use Web::App;

my $scgi = SCGI.new(:port(8118), :PSGI); #:debug
my $app = Web::App.new($scgi);

my $handler = sub ($context) {
  $context.set-status(200);
  $context.content-type('text/plain');
  my $name = $context.get(:default<World>, 'name');
  $context.send("Hello $name\n");
  $context.send("How are you today?\n");
}

$app.run: $handler;

