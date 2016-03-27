unit class Web::App;

use Web::App::Context;
use MIME::Types;

has $.engine; ## The engine to handle requests.
has $!mime;   ## MIME::Types object. Initialized on first use of mime().

## Create a new object, pass it an engine object.
method new ($engine) {
  return self.bless(*, :$engine);
}

## Load a mime file.
method load-mime ($ufile) {
  $!mime = MIME::Types.new($ufile);
}

## Return the MIME::Types object.
## If it hasn't been created, we will try to
## find a default mime.types, otherwise, we will bail.
##
## TODO: Modify MIME::Types to use built-in mime.types file as default.
##
## This is currently hard coded to the /etc/mime.types,
## which honestly, is pretty Linux/Unix specific.
## Please, for the love of whatever is sacred to you,
## manually call load-mime() in your scripts!
method mime  {
  if ! defined $!mime {
    if "/etc/mime.types".IO !~~ :f {
      die "Attempt to use Context.mime before loading the mime.types file.";
    }
    self.load-mime("/etc/mime.types");
  }
  return $!mime;
}

## We support multiple versions of run() in sub-classes.
## The default version of run is for a single handler.
## It only supports raw code blocks, and no rules.
## If you need more functionality, look at
## using the Web::App::Dispatch subclass.
multi method run (&app) {
  my $handler = sub (%env) {
    my $context = Web::App::Context.new(%env, self);
    my $out = app($context); ## Call our routine.
    ## If there is no response body, and the routine returned a string,
    ## then we use the string as the response body.
    if $context.res.body.elems == 0 && $out ~~ Str {
      $context.send($out);
    }
    if (!$context.res.status) { $context.res.set-status(200); }
    if (!$context.res.has-header('content-type') && !$context.res.has-header('location')) {
      $context.content-type: 'text/html';
    }
    return $context.res.response;
  }
  self._dispatch: $handler;
}

## The actual handler dispatch code.
## Works with engines that support
## a handle() method, or app() and run() methods.
method _dispatch ($handler) {
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

## End of class.
