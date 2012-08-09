class WWW::App;

use WWW::App::Context;

has $.engine; ## The engine to handle requests.
has @!rules;  ## Optional rules for the dispatch-based run();

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

## A version of run for a single handler.
## Only supports code blocks, and no rules.
## If you need more functionality, look at
## using the dispatch rules version of run();
multi method run (&app) {
  my $handler = sub (%env) {
    my $context = WWW::App::Context.new(%env, self);
    app($context); ## Call our method. We don't care what it returns.
    if (!$context.res.status) { $context.res.set-status(200); }
    if (!$context.res.has-header('location') && !$context.res.has-header('content-type')) {
      $context.content-type: 'text/html';
    }
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
method process-handler ($handler, $context) {
  my $processed = False;
  if $handler ~~ Callable {
    $processed = $handler($context);
  }
  elsif $handler.can('handle') {
    $processed = $handler.handle($context);
  }
  return $processed;
}

## A private method used by the run() below.
method !process-actions ($rules, $context) {
  my $res     = $context.res;
  my $handled = False;
  my $last    = False;
  ## Add extra headers.
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
  ## Redirect the client to a new URL.
  if $rules<redirect> {
    my $status = 302;
    if $rules<status> { $status = $rules<status>; }
    $context.redirect($rules<redirect>, $status);
    return [ True, True ]; ## A redirect overrides everything else.
  }
  ## Set the HTTP status code.
  if $rules<status> {
    $context.set-status($rules<status>);
  }
  ## Set the MIME Content-Type
  if $rules<mime> {
    $res.content-type($rules<mime>);
  }
  ## Send a file to the client.
  if $rules<sendfile> {
    my $filename;
    my $file;
    my $content;
    my $type;
    if $rules<sendfile> ~~ Hash {
      my $sendfile = $rules<sendfile>;
      $filename = $sendfile<filename>;
      ## Required stuff.
      if $sendfile.exists('content') {
        $content = $sendfile<content>;
      }
      elsif $sendfile.exists('file') {
        $file = $sendfile<file>;
      }
      ## Optional stuff.
      if $sendfile.exists('type') {
        $type = $sendfile<type>;
      }
    }
    else {
      $file = $rules<sendfile>;
      $filename = $file.split('/').pop;
    }
    my $sent = False;
    if defined $content {
      $context.send-file($filename, :$content, :$type);
      $sent = True;
    }
    elsif defined $file && $file.IO ~~ :f {
      $context.send-file($filename, :$file, :$type);
      $sent = True;
    }
    if ($sent) {
      return [ True, True ]; ## A sendfile overrides all else.
    }
  }
  ## Send a string as the return content.
  if $rules<send> {
    my $text = ~$rules<send>;
    $context.send($text);
    $handled = True;
    $last    = True;
  }
  ## Set the return content to the contents of a text file.
  ## Useful for say CSS or Javascript resource files.
  if $rules<slurp> {
    if $rules<slurp>.IO ~~ :f {
      $context.send(slurp($rules<slurp>));
      $handled = True;
      $last    = True;
    }
  }
  ## The final test is to call the handler, passing it the $req, $res
  ## and $rules (for further optional processing.)
  ## The handler must return True if it handled the process, or False
  ## if it didn't.
  if $rules.exists('handler') {
    $context.rules = $rules;
    my $processed = self.process-handler($rules<handler>, $context);
    if $processed {
      ## We are handled, and should be considered the last.
      $handled = True;
      $last    = True;
    }
  }
  ## Override the last setting.
  if $rules<continue> {
    $last = False;
  }
  ## Explicitly set the last setting.
  elsif $rules.exists('last') {
    $last = $rules<last>;
  }
  ## Explicitly set the handled setting.
  if $rules.exists('handled') {
    $handled = $rules<handled>;
  }
  return [ $handled, $last ];
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
      my $last;
      ($handled, $last) = self!process-actions($rules, $context);
      if $last { last; }
    }
    if !$handled && defined $default {
      my $last; ## Ignored here, as this IS the last.
      ($handled, $last) = self!process-actions($default, $context);
    }

    ## Default status.
    if (!$res.status) {
      my $status = 500;
      if $handled { $status = 200; }
      $res.set-status($status); 
    }

    ## Default content-type.
    if (!$res.has-header('location') && !$res.has-header('content-type')) {
      $res.content-type: 'text/html';
    }

    return $res.response;
  }
  self!dispatch: $controller;
}

## End of class.
