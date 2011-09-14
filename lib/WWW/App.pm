class WWW::App;

use WWW::Request;
use WWW::Response;

has $.engine; ## The engine to handle requests.
has @!handlers; ## Optional handlers dispatched based on rules.

method new ($engine) {
  return self.bless(*, :$engine);
}

## A version of run for a single handler.
multi method run (&app) {
  my $handler = sub (%env) {
    my $req = WWW::Request.new(%env);
    my $res = WWW::Response.new();
    app($req, $res); ## Call our method. We don't care what it returns.
    if (!$res.status) { $res.set-status(200); }
    return $res.response;
  }
  self.dispatch: $handler;
}

## The actual handler dispatch code.
method dispatch ($handler) {
  if $!engine.can('handle') {
    $!engine.handle: $handler;
  }
  elsif $!engine.can('app') && $!engine.can('run') {
    $!engine.app($handler);
    $!engine.run;
  }
  else {
    die "Sorry, unknown engine type.";
  }
}

## Add a dispatch rule
method add-dispatch (*%rules) {
  my $rules = %rules;
  if %rules.exists('handler') {
    @!handlers.push: $rules;
  }
}

## Add a dispatch rule.
method insert-dispatch (*%rules) {
  my $rules = %rules;
  if %rules.exists('handler') {
    @!handlers.unshift: $rules;
  }
}

## A version of run that dispatches based on rules.
multi method run () {
  my $controller = sub (%env) {
    my $req = WWW::Request.new(%env);
    my $res = WWW::Response.new();
    my &handler;
    for @!handlers -> $handler {
      if $handler<path> && $req.path ~~ $handler<path> {
        &handler = $handler<handler>;
        last;
      }
      elsif $handler<default> {
        &handler = $handler<handler>;
        ## We don't stop, as other rules override the default.
      }
      ## TODO: Add more rules.
    }
    handler($req, $res); ## Call our found handler.
    if (!$res.status) { $res.set-status(200); }
    return $res.response;
  }
  self.dispatch: $controller;
}

