#!/usr/bin/env perl6

BEGIN { 
  @*INC.push: './lib'; 
  @*INC.push: './test';
}

use MethodHandler;

class TestHandler is MethodHandler {
  method handle_test ($context, *@params) {
    $res.content-type: 'text/plain';
    $res.send("This is a test.");
  }
  method handle_duh ($context, *@params) {
    $res.content-type: 'text/html';
    $res.send("<html><head><title>A Test</title></head><body>A Test</body></html>");
  }
}

use HTTP::Easy::PSGI;
use WWW::App;

my $psgi = HTTP::Easy::PSGI.new(:port(8080));
my $app = WWW::App.new($psgi);

my $main = sub ($context) {
  $context.set-status(200);
  $context.content-type('text/plain');
  my $name = $context.get(:default<World>, 'name');
  $context.say("Hello $name");
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

