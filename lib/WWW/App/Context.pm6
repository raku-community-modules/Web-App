class WWW::App::Context;

## This is a special object returned to WWW::App handlers, which contains
## a bunch of magic wrapper functions, to make life easier.
## It also contains the Request and Response objects.

use WWW::Request;
use WWW::Response;

has $.req handles <get file path host>;             ## WWW::Request
has $.res handles <set-status content-type send>;   ## WWW::Response
has $.app handles <load-mime mime>;                 ## WWW::App or subclass

has $.rules is rw; ## Optional. Set to dispatch rules that sent us here.

method new (%env, $app) {
  my $req = WWW::Request.new(%env);
  my $res = WWW::Response.new();
  self.bless(*, :$req, :$res, :$app);
}

## Magic methods, extending the functionality possible in the
## standard Request/Response objects.

## A magical version of redirect, based on ww6.
method redirect (Stringy $url, $status=302) {
  if $url !~~ /^\w+'://'/ {
    my $proto = $.req.proto;
    my $relurl = ''; ## 
    my $port;
    if $url ~~ /^(https?)[':'(\d+)]$/ {
      $proto = $0.Str;
      $relurl = $.req.uri;
      if $1 {
        $port = +$1;
      }
    }
    else {
      if $url !~~ /^\// { $relurl = '/'; }
      $relurl ~= $url;
      if $.req.port != 80 | 443 { $port = $.req.port; }
    }
    $url = $proto ~ '://' ~ $.req.host;
    if $port { $url ~= ":$port" }
    $url ~= $relurl;
  }
  $.res.redirect($url, $status);
}

## A magical version of send-file, that automatically determines
## the file-type if you don't pass it one, using the mime() method.
method send-file ($filename, :$file, :$content, :$type, Bool :$cache) {
  my $ctype;
  if $type { $ctype = $type; }
  else {
    my $ext = $filename.split('.').pop;
    $ctype = $.app.mime.type($ext);
    if (!$ctype) {
      $ctype = 'application/octet-stream';
    }
  }
  $.res.send-file($filename, :$file, :$content, :$cache, :type($ctype));
}

## Use this if for some reason we don't want to add the Content-Length
## header automatically when building our response.
method no-length ()
{
  $.res.auto-length = False;
}

## End of library.
