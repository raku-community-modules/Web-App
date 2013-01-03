# WWW::App

## Introduction

WWW::App is a simple web application library for Perl 6, that uses
the PSGI interface. It replaces my older WebRequest library, and is
meant as a more generic framework to replace my ww6 framework (which
is officially retired.) Like ww6, it is very flexible, unlike it, it
doesn't try to be everything under the sun.

It consists of a few libraries, the most important of which are:

  * WWW::Request   

    Contains information about the HTTP request.

  * WWW::Response  

    Builds a PSGI compliant response.

  * WWW::App       

    A minimal web framework, uses backend engines.

  * WWW::App::Dispatch

    An extension of WWW::App support advanced dispatch rules.

The first two libraries can be used by themselves if the full functionality
of WWW::App is not required.

## WWW::Request

WWW::Request is similar to CGI.pm or Plack::Request from Perl 5.

It supports PSGI (recommended), SCGI, FastCGI, mod-perl6 and standard CGI. 
Currently only supports GET and non-multipart POST.
I am planning on adding multi-part POST including file uploads,
and some optional magic parameters similar to the ones in PHP.

## WWW::Response

An easy to use object that builds a PSGI compliant response.
Supports some quick methods such as content-type() and
redirect() to automatically create appropriate headers.

## WWW::App

Puts the above two together, along with a backend engine,
and a context helper object, and makes building web apps really easy.

It supports any backend engine that provides a PSGI compliant interface,
and a handle() method that takes a subroutine as a parameter (the subroutine
must take a hash representing the environment), or an app() method that takes
the aforementioned subroutine as a parameter, and a run() method to start
processing requests.

See the list below for details of which libraries to use.

The context helper object provides wrappers to the Request and Response objects,
including some magic functions that enable features otherwise not possible,
such as a far more advanced redirect() method.

## WWW::App::Dispatch

WWW::App::Dispatch is an extension of WWW::App, that  also supports advanced
action dispatch based on rules.

Rather than supporting a single handler, you can have multiple rules, 
which will perform specific actions, including running handlers, 
based on environment variables such as the URL path, host, or protocol.

Actions can include redirection, setting content-type, adding headers,
or calling a handler (either a code block, or an object with a 
handle() method.) A default handler can be called if no rules are matched.

## Status

Everything listed above works. For an even more complete Web Framework, see
[WWW::App::MVC](https://github.com/supernovus/perl6-www-app-mvc/), 
which is an MVC framework built upon WWW::App::Dispatch.

## Requirements

 * [MIME::Types](https://github.com/supernovus/perl6-mime-types)

## Connector Engine Modules

None of the connector modules are required by default, so you'll need to
install them yourself whichever one you want to use via Panda.

  * [SCGI](https://github.com/supernovus/SCGI)

    Offers the best integration with existing web servers, such as
    Apache, lighttpd, etc. It's like FastCGI, only simpler and faster.

  * [FastCGI](https://github.com/supernovus/perl6-fastcgi)

    A complex and comprehensive protocol, the Perl 6 implementation is
    considerably slower than SCGI, but offers more advanced features.

  * [HTTP::Easy](http://github.com/supernovus/perl6-http-easy)

    WWW::App supports the HTTP::Easy::PSGI adapter, which provides a nice
    clean standalone HTTP server with PSGI application support.
    This provides GET and POST support including multipart/form-data.

  * [HTTP::Server::Simple](http://github.com/mberends/http-server-simple)

    This library has not been tested, but WWW::App should be able to work with
    the HTTP::Server::Simple::PSGI interface without any modifications.

## Note

You can use WWW::Request and WWW::Response with whatever backend
you want, including regular CGI, but I don't recommend using CGI.
It's horridly slow, and very evil. I recommend using one of the above
libraries instead. Also, WWW::App is a nice wrapper, and requires at
least one of the above optional modules to be used.

## Examples

### Example 1

This is an example of the use of WWW::App and it's wrapper magic.
Handlers for WWW::App are sent a special WWW::App::Context object
which wraps the Request and Response, and provides some extra magic
that makes life a lot easier.

```perl
  use SCGI;
  use WWW::App;

  my $scgi = SCGI.new(:port(8118));
  my $app = WWW::App.new($scgi);

  my $handler = sub ($context) {
    given $context.path {
      when '/' {
        $context.content-type('text/plain');
        $context.send("Request parameters:");
        $context.send($context.req.params.fmt('%s: %s', "\n"));
        my $name = $context.get('name');
        if $name {
          $context.send("Hello $name");
        }
      }
      default {
        ## We don't support anything else, send them home.
        $context.redirect('/');
      }
  }

  $app.run: $handler;

  ## End of script.
```

### Example 2

This example is using WWW::App::Dispatch and some of its many rules.

```perl

  class RedirectHandler {
    has $.site;
    method handle ($context) {
      $context.redirect($.site);
    }
  }

  use SCGI;
  use WWW::App::Dispatch;
  
  my $scgi = SCGI.new(:port(8118));
  my $app  = WWW::App::Dispatch.new($scgi);

  my $main = sub ($context) {
    $context.set-status(200);
    $context.content-type('text/plain');
    my $name = $context.get(:default<World>, 'name');
    $context.send("Hello $name");
  }

  $app.add(:handler($main), :default); ## Gets called if no other rules match.

  ## Let's add an object-based handler on the '/test' URL path.
  my $test = RedirectHandler.new(:site<http://huri.net>);
  $app.add(:path</test>, :handler($test));

  ## Another form of redirect, using an action rule.
  $app.add(:proto<http>, :redirect<https>);

  ## A slurp handler.
  $app.add(:path</slurp>, :slurp<./webroot/hello.text>);

  ## Send a file to the client browser.
  $app.add(:path</file>, :sendfile<./webroot/data.zip>);

  ## Okay, let's run the app.
  $app.run;

  ## End of script.
```

### Example 3

This is an example of using WWW::Request and WWW::Response together with
HTTP::Easy's PSGI adapter, without using WWW::App as a wrapper.

```perl
  use HTTP::Easy::PSGI;
  use WWW::Request;
  use WWW::Response;

  my $http = HTTP::Easy::PSGI.new(); ## Default port is 8080.

  my $handler = sub (%env) {
    my $req = WWW::Request.new(%env);
    my $res = WWW::Response.new();
    $res.set-status(200);
    $res.add-header('Content-Type' => 'text/plain');
    $res.send("Request parameters:");
    $res.send($req.params.fmt('%s: %s', "\n"));
    my $name = $req.get('name');
    if $name {
      $res.send("Hello $name");
    }
    return $res.response;
  }

  $http.handle: $handler;

  ## End of script.
```

### Further Examples

For more examples, including using other backends, more dispatch
rules, and lots of other cool stuff, see the examples in the 'test' folder.

## TODO

  * Fix binary uploads. They need to use Buf instead of Str.
  * Add more pre-canned headers and automation to WWW::Response.
    Sending files back to the client should be made easy.
  * Add more useful helpers to WWW::App::Context.

## Author

Timothy Totten, supernovus on #perl6, https://github.com/supernovus/

## License

Artistic License 2.0

