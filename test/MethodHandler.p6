#!/usr/bin/env perl6

BEGIN { @*INC.push: './lib'; }

use WWW::App::MethodHandler;

class TestHandler is WWW::App::MethodHandler {
  method handle_test (:$res, :$req, :$def, *@params) {
    $res.content-type: 'text/plain';
    $res.say("This is a test.");
  }
  method handle_duh (:$res, :$req, :$def, *@params) {
    $res.content-type: 'text/html';
    $res.say("<html><head><title>A Test</title></head><body>A Test</body></html>");
  }
}

use HTTP::Easy::PSGI;
use WWW::App;

my $psgi = HTTP::Easy::PSGI.new(:port(8080));
my $app = WWW::App.new($psgi);

my $main = sub ($req, $res, $rules?) {
  $res.set-status(200);
  $res.content-type('text/plain');
  my $name = $req.get(:default<World>, 'name');
  $res.say("Hello $name");
}

## The :default only gets called if no other
## handler is found.
$app.add(:handler($main), :default);

## Now let's load an object-based handler.
## This one uses it's own methods to determine
## if it can handle the request or not.
my $test = TestHandler.new;
$app.add(:handler($test));

$app.run;

