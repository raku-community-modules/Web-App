#!/usr/bin/env perl6

BEGIN { @*INC.push: './lib'; }

use SCGI;
use WWW::App;

my $scgi = SCGI.new(:port(8118), :PSGI, :!strict, :debug);
my $app = WWW::App.new($scgi);

my $test = sub ($req, $res) {
  $res.set-status(301);
  $res.add-header('Redirect'=>'http://huri.net/');
}

$app.add-dispatch(:path</test>, :handler($test));

my $main = sub ($req, $res) {
  $res.set-status(200);
  $res.content-type('text/plain');
  my $name = $req.get(:default<World>, 'name');
  $res.say("Hello $name");
}

$app.add-dispatch(:path</>, :handler($main), :default);

$app.run;

