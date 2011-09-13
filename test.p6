#!/usr/bin/env perl6

BEGIN { @*INC.push: './lib'; }

use WWW::App;

my $app = WWW::App.new(:SCGI(8118), :debug);

my $handler = sub ($req, $res) {
  $res.set-status(200);
  $res.content-type('text/plain');
  my $name = $req.get(:default<World>, 'name');
  $res.say("Hello $name");
}

$app.run: $handler;

