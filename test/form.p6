#!/usr/bin/env perl6

BEGIN { @*INC.push: './lib'; }

#use SCGI;
use HTTP::Easy::PSGI;
use WWW::App;

my $http = HTTP::Easy::PSGI.new(:debug);
#my $scgi = SCGI.new(:port(8118), :PSGI, :!strict, :debug);
my $app = WWW::App.new($http);

my $handler = sub ($req, $res) {
  $res.set-status(200);
  $res.content-type('text/html');
  my $img = $req.file('myimg');
  my $start = slurp('test/form-start.html');
  $res.send($start);
  if ($img) {
    $res.send("Filename: "~$img.temppath);
  }
  my $finish = slurp('test/form-end.html');
  $res.send($finish);
}

$app.run: $handler;

