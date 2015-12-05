#!/usr/bin/env perl6

use lib 'lib';

#use SCGI;
use HTTP::Easy::PSGI;
use Web::App;

my $http = HTTP::Easy::PSGI.new(:debug);
#my $scgi = SCGI.new(:port(8118), :PSGI); #:debug
my $app = Web::App.new($http);

my $handler = sub ($context) {
  given $context.path {
    when '/' {
      $context.set-status(200);
      $context.content-type('text/html');
      my $file = $context.file('myfile');
      my $start = slurp('test/form-start.html');
      $context.send($start);
      if ($file) {
        my $ftype = $file.header('Content-Type');
        if $ftype ~~ / ^ text / {
          $context.send("<pre>");
          $context.send($file.slurp);
          $context.send("</pre>");
        }
        elsif $ftype ~~ / ^ image / {
          my $filename = $file.temppath.split('/').pop; ## Get the basename.
          $filename ~= '/';                             ## Add a slash.
          $filename ~= $file.filename;                  ## Add the filename.
          $context.send("<img src=\"uimages/$filename\" />");
        }
        else {
          $context.send("File uploaded to: "~$file.temppath);
        }
      }
      my $finish = slurp('test/form-end.html');
      $context.send($finish);
    }
    when /uimages/ {
      ## Serve up some images.
      ## TODO: make this use the new file serving methods once they
      ## are implemented.
      my ($fakens, $tempfile, $filename) = $context.path.split('/');
      $context.send-file($filename, :file($tempfile));
    }
    default {
      $context.set-status(404);
    }
  }
}

$app.run: $handler;

