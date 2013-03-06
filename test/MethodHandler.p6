#!/usr/bin/env perl6

BEGIN { 
  @*INC.push: './lib'; 
  @*INC.push: './test';
}

use MethodHandler;

class TestHandler is MethodHandler {
  method handle_test ($context, *@params) {
    $context.content-type: 'text/plain';
    $context.send("This is a test.");
  }
  method handle_duh ($context, *@params) {
    $context.content-type: 'text/html';
    $context.send("<html><head><title>A Test</title></head><body>A Test</body></html>");
  }
}

use HTTP::Easy::PSGI;
#use SCGI;
use Web::App::Dispatch;

my $http = HTTP::Easy::PSGI.new(:port(8080));
#my $scgi = SCGI.new(:port(8118), :PSGI);
my $app = Web::App::Dispatch.new($http);

my $main = sub ($context) {
  $context.set-status(200);
  $context.content-type('text/plain');
  my $name = $context.get(:default<World>, 'name');
  $context.send("Hello $name");
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

