#!/usr/bin/env perl6

BEGIN { @*INC.push: './lib'; }

use HTTP::Server::Simple::PSGI;
use WWW::App;

my $psgi = HTTP::Server::Simple::PSGI.new(8080);
my $app = WWW::App.new($psgi);

my $handler = sub ($req, $res) {
  $res.set-status(200);
  $res.content-type('text/plain');
  my $name = $req.get(:default<World>, 'name');
  $res.say("Hello $name");
}

$app.run: $handler;

