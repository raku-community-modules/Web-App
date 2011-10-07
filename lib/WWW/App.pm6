class WWW::App;

use WWW::App::Context;

has $.engine; ## The engine to handle requests.
has @!rules;  ## Optional rules for the dispatch-based run();

## Create a new object, pass it an engine object.
method new ($engine) {
  return self.bless(*, :$engine);
}

## A version of run for a single handler.
## Only supports code blocks, and no rules.
## If you need more functionality, look at
## using the dispatch rules version of run();
multi method run (&app) {
  my $handler = sub (%env) {
    my $context = WWW::App::Context.new(%env, self);
    app($context); ## Call our method. We don't care what it returns.
    if (!$context.res.status) { $context.res.set-status(200); }
    return $context.res.response;
  }
  self!dispatch: $handler;
}

## The actual handler dispatch code.
## Works with engines that support
## a handle() method, or app() and run() methods.
method !dispatch ($handler) {
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

## Add a dispatch rule to the end of the list.
method add (*%rules) {
  my $rules = %rules;
  @!rules.push: $rules;
}

## Add a dispatch rule to the beginning of the list.
method insert (*%rules) {
  my $rules = %rules;
  @!rules.unshift: $rules;
}

## Handle code blocks or objects as handlers.
method !process ($handler, $context) {
  my $processed = False;
  if $handler ~~ Callable {
    $processed = $handler($context);
  }
  elsif $handler.can('handle') {
    $processed = $handler.handle($context);
  }
  return $processed;
}

## A version of run that dispatches based on rules.
## In addition to running handlers, it can also do
## magic like redirection, setting content-type, and
## adding headers. It's based off of ww6 and its
## Dispatch plugin.
multi method run () {
  my $controller = sub (%env) {
    my $context = WWW::App::Context.new(%env, self);
    my $req = $context.req; 
    my $res = $context.res;
    my $default; ## Used if no other rules match.
    my $handled = False;
    for @!rules -> $rules {
      ## First, check for a default handler.
      ## The default will be run only if no other
      ## rules match. For handlers that should be
      ## run all the time, include no settings.
      if $rules<default> && not defined $default {
        $default = $rules;
        next; ## The default isn't filtered, nor run in the loop.
      }
      ## Next, let's find handlers to run, based on rules.
      if $rules<path> && $req.path !~~ $rules<path> { next; }
      if $rules<host> && $req.host !~~ $rules<host> { next; }
      if $rules<proto> && $req.proto !~~ $rules<proto> { next; }
      if $rules<notproto> && $req.proto ~~ $rules<notproto> { next; }
      ## Okay, if we've made it this far, we've passed all the rules so far.
      ## Now we can deal with actions, such as setting content-type, adding
      ## headers, redirecting. NOTE: Redirection ends all other processing.
      if $rules<headers> {
        my $headers = $rules<headers>;
        if $headers ~~ Array {
          for @($headers) -> $header {
            if $header ~~ Pair {
              $res.add-header($header);
            }
          }
        }
        elsif $headers ~~ Pair {
          $res.add-header($headers);
        }
      }
      if $rules<redirect> {
        my $status = 302;
        if $rules<status> { $status = $rules<status>; }
        $context.redirect($rules<redirect>, $status);
        $handled = True; ## A redirection counts as a handler.
        last; ## A redirect ends the rule parsing.
      }
      if $rules<mime> {
        $res.content-type($rules<mime>);
      }
      ## The final test is to call the handler, passing it the $req, $res
      ## and $rules (for further optional processing.)
      ## The handler must return True if it handled the process, or False
      ## if it didn't.
      if $rules.exists('handler') {
        $context.rules = $rules;
        my $processed = self!process($rules<handler>, $context);
        if $processed {
          $handled = True;
          if ($rules<last>) { last; } ## Stop processing further rules.
        }
      }
    }
    if !$handled && defined $default {
      $context.rules = $default;
      $handled = self!process($default<handler>, $context);
    }
    if (!$res.status) {
      my $status = 500;
      if $handled { $status = 200; }
      $res.set-status($status); 
    }
    return $res.response;
  }
  self!dispatch: $controller;
}

## End of class.
