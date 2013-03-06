#!/usr/bin/env perl6

BEGIN { @*INC.push: './lib'; }

class TestHandler {
  has $.site;
  method handle ($context) {
    $context.redirect($.site);
  }
}

use SCGI;
#use HTTP::Easy::PSGI;
use Web::App::Dispatch;

my $scgi = SCGI.new(:port(8118), :PSGI); #:debug
#my $http = HTTP::Easy::PSGI.new(:debug);
my $app = Web::App::Dispatch.new($scgi);

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
my $test = TestHandler.new(:site<http://huri.net>);
$app.add(:path</test>, :handler($test));

## Another form of redirect, as supplied by Web::App itself.
$app.add(:path</perl6>, :redirect<http://perl6.org/>);

## A slurp handler.
$app.add(:path</slurp>, :slurp<./test/test-slurp.txt>);

## A send handler.
$app.add(:path</send>, :send<This is a test>);

## A sendfile handler.
$app.add(:path</sendfile>, :sendfile<./test/test-file.xml>);

$app.run;

