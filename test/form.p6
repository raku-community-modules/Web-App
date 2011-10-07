#!/usr/bin/env perl6

BEGIN { @*INC.push: './lib'; }

#use SCGI;
use HTTP::Easy::PSGI;
use WWW::App;

my $http = HTTP::Easy::PSGI.new(:debug);
#my $scgi = SCGI.new(:port(8118), :PSGI, :!strict, :debug);
my $app = WWW::App.new($http);

my $handler = sub ($context) {
  given $context.path {
    when '/' {
      $context.set-status(200);
      $context.content-type('text/html');
      my $img = $context.file('myfile');
      my $start = slurp('test/form-start.html');
      $context.send($start);
      if ($img) {
        $context.send("Filename: "~$img.temppath);
      }
      my $finish = slurp('test/form-end.html');
      $context.send($finish);
    }
    default {
      $context.set-status(404);
    }
  }
}

$app.run: $handler;

