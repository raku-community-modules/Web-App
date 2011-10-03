#!/usr/bin/env perl6

BEGIN { @*INC.push: './lib'; }

use SCGI;
use WWW::App;

my $scgi = SCGI.new(:port(8118), :PSGI, :!strict, :debug);
my $app = WWW::App.new($scgi);

my $handler = sub ($req, $res) {
  $res.set-status(200);
  $res.content-type('text/html');
  my $img = $req.file('myimg');
  $res.say("<html><head><title>Form test</title></head><body>");
  $req.say('<form method="POST">');
  $req.say('<input type="file" name="myfile" />');
  $req.say('<input type="submit" value="Go" />');
  if ($img) {
    $req.say("Filename: "~$img.temppath);
  }
  $req.say("</form></body></html>");
}

$app.run: $handler;

