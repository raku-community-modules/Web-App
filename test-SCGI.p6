#!/usr/bin/env perl6

BEGIN { @*INC.push: './lib'; }

use SCGI;
use WWW::App;

my $scgi = SCGI.new(:port(8118), :PSGI, :!strict, :debug);
my $app = WWW::App.new($scgi);

my $handler = sub ($req, $res) {
  $res.set-status(200);
  $res.content-type('text/plain');
  my $name = $req.get(:default<World>, 'name');
  $res.say("Hello $name");
}

$app.run: $handler;

