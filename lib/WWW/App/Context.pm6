class WWW::App::Context;

## This is a special object returned to WWW::App handlers, which contains
## a bunch of magic wrapper functions, to make life easier.
## It also contains the Request and Response objects.

use WWW::Request;
use WWW::Response;

has $.req;   ## Will contain the WWW::Request object.
has $.res;   ## Will contain the WWW::Response object.
has $.app;   ## Expert use only, contains the WWW::App object that created us.

has $.rules is rw; ## Optional. Set to dispatch rules that sent us here.

method new (%env, $app) {
  my $req = WWW::Request.new(%env);
  my $res = WWW::Response.new();
  self.bless(*, :$req, :$res, :$app);
}

## Magic methods using both Request and Response

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

## Response wrapper methods

method set-status ($status) {
  $.res.set-status(+$status);
}

method content-type (Str $type?) {
  $.res.content-type($type);
}

method send (Str $text) {
  $.res.send($text);
}

## Request wrapper methods

method get (Stringy :$default, Bool :$multiple, *@keys) {
  $.req.get(:$default, :$multiple, |@keys);
}

method file (Stringy $field, Bool :$multiple) {
  $.req.file($field, :$multiple);
}

method path {
  $.req.path;
}

method host {
  $.req.host;
}

## End of library.
