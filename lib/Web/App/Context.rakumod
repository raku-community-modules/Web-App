unit class Web::App::Context;

## This is a special object returned to Web::App handlers, which contains
## a bunch of magic wrapper functions, to make life easier.
## It also contains the Request and Response objects.

use Web::Request;
use Web::Response;

has $.req handles <get file path host>;             ## Web::Request
has $.res handles <set-status content-type send>;   ## Web::Response
has $.app handles <load-mime mime>;                 ## Web::App or subclass

has $.rules is rw; ## Optional. Set to dispatch rules that sent us here.

method new(%env, $app) {
    my $req = Web::Request.new(%env, :allow-cgi($app.allow-cgi));
    my $res = Web::Response.new();
    self.bless(*, :$req, :$res, :$app);
}

## Magic methods, extending the functionality possible in the
## standard Request/Response objects.

## A magical version of redirect.
method redirect(Stringy $url is copy, $status=302) {
    if $url !~~ /^\w+'://'/ {
        my $proto = $.req.proto;
        my $relurl = ''; ## 
        my $port;
        if $url ~~ /^(https?)[':'(\d+)]$/ {
            $proto = $0.Str;
            $relurl = $.req.uri;
            $port = +$1 if $1;
        }
        else {
            $relurl = '/' if $url !~~ /^\//;
            $relurl ~= $url;
            $port = $.req.port unless $.req.port == 80 | 443;
        }
        $url = $proto ~ '://' ~ $.req.host;
        $url ~= ":$port" if $port;
        $url ~= $relurl;
    }
    $.res.redirect($url, $status)
}

## A magical version of send-file, that automatically determines
## the file-type if you don't pass it one, using the mime() method.
method send-file($filename, :$file, :$content, :$type, Bool :$cache) {
    my $ctype;
    if $type {
        $ctype = $type;
    }
    else {
        my $ext = $filename.split('.')[*-1] || '';
        $ctype = $.app.mime.type($ext);
        $ctype = 'application/octet-stream' unless $ctype;
    }
    $.res.send-file($filename, :$file, :$content, :$cache, :type($ctype))
}

## Use this if for some reason we don't want to add the Content-Length
## header automatically when building our response.
method no-length() {
    $.res.auto-length = False;
}

# vim: expandtab shiftwidth=4
