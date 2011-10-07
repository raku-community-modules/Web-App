#!/usr/bin/env perl6

BEGIN { @*INC.push: './lib'; }

use SCGI;
#use HTTP::Easy::PSGI;
use WWW::App;

#my $http = HTTP::Easy::PSGI.new(:debug);
my $scgi = SCGI.new(:port(8118), :PSGI, :!strict, :debug);
my $app = WWW::App.new($scgi);

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
      my $ctype;
      given $filename {
        ## We support the most common image types used on the web.
        when /\.jpe?g?$/ { $ctype = 'image/jpeg';    }
        when /\.gif$/    { $ctype = 'image/gif';     }
        when /\.png$/    { $ctype = 'image/png';     }
        when /\.svg$/    { $ctype = 'image/svg+xml'; }
      }
      $context.content-type("$ctype; name=\"$filename\"");
      my $disp = "inline; filename=\"$filename\"";
      $context.add-header('Content-Disposition' => $disp);
      $context.add-header('Cache-Control' => 'no-cache');
      my $content = slurp("/tmp/$tempfile");
      $context.send($content);
    }
    default {
      $context.set-status(404);
    }
  }
}

$app.run: $handler;

