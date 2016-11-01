# Web -- A Web Application foundation for Perl 6 [![Build Status](https://travis-ci.org/supernovus/perl6-web.svg?branch=master)](https://travis-ci.org/supernovus/perl6-web)

## Introduction

Web is a simple web application library set for Perl 6, that uses
the PSGI interface. It is based on work done for the original Web.pm project,
as well as WebRequest, and November.

It consists of a few libraries, the most important of which are:

  * Web::Request   

    Contains information about the HTTP request.

  * Web::Response  

    Builds a PSGI compliant response.

  * Web::App       

    A minimal web framework, uses backend engines (see below).

  * Web::App::Dispatch

    An extension of Web::App support advanced dispatch rules.

## Web::Request

Web::Request is similar to CGI.pm or Plack::Request from Perl 5.

It supports P6SGI 0.7Draft (recommended), P6SGI 0.4Draft, PSGI Classic, SCGI standalone, FastCGI standalone, and mod-perl6.
It can be forced to use standard CGI, but that's really not recommended.
Currently only supports GET and non-multipart POST.
We are planning on adding multi-part POST including file uploads,
and some optional magic parameters similar to the ones in PHP.

## Web::Response

An easy to use object that builds a P6SGI/PSGI compliant response.
Supports some quick methods such as content-type() and
redirect() to automatically create appropriate headers.

## Web::App

Puts the above two together, along with a backend engine,
and a context helper object, and makes building web apps really easy.

It supports any backend engine that provides a P6SGI/PSGI compliant interface,
and a handle() method that takes a subroutine as a parameter (the subroutine
must take a hash representing the environment), or an app() method that takes
the aforementioned subroutine as a parameter, and a run() method to start
processing requests.

See the list below for details of which libraries to use.

The context helper object provides wrappers to the Request and Response objects,
including some magic functions that enable features otherwise not possible,
such as a far more advanced redirect() method.

## Web::App::Dispatch

Web::App::Dispatch is an extension of Web::App, that  also supports advanced
action dispatch based on rules.

Rather than supporting a single handler, you can have multiple rules, 
which will perform specific actions, including running handlers, 
based on environment variables such as the URL path, host, or protocol.

Actions can include redirection, setting content-type, adding headers,
or calling a handler (either a code block, or an object with a 
handle() method.) A default handler can be called if no rules are matched.

## Related Projects and Extensions

 * [Web::App::MVC](https://github.com/supernovus/perl6-web-app-mvc/)

   A MVC web framework built upon Web::App::Dispatch.

 * [Web::App::Ballet](https://github.com/supernovus/perl6-web-app-ballet/)

   A Dancer-like interface to Web::App::Dispatch. NOTE: This project will
   be merged with [Bailador](https://github.com/tadzik/Bailador) in the near future.

## Requirements

 * [MIME::Types](https://github.com/supernovus/perl6-mime-types)
 * [PSGI](https://github.com/supernovus/perl6-psgi)

## Connector Engine Modules

None of the connector modules are required by default, so you'll need to
install them yourself whichever one you want.

  * [SCGI](https://github.com/supernovus/SCGI)

    Offers the best integration with existing web servers, such as
    Apache, lighttpd, etc. It's like FastCGI, only simpler and faster.

  * [FastCGI](https://github.com/supernovus/perl6-fastcgi)

    A complex and comprehensive protocol, the Perl 6 implementation is
    considerably slower than SCGI, but offers more advanced features.

  * [HTTP::Easy](http://github.com/supernovus/perl6-http-easy)

    Web::App supports the HTTP::Easy::PSGI adapter, which provides a nice
    clean standalone HTTP server with PSGI application support.
    This provides GET and POST support including multipart/form-data.

  * [HTTP::Server::Simple](http://github.com/mberends/http-server-simple)

    This library has not been tested, but Web::App should be able to work with
    the HTTP::Server::Simple::PSGI interface without any modifications.

## Examples

### Example 1

This is an example of the use of Web::App and it's wrapper magic.
Handlers for Web::App are sent a special Web::App::Context object
which wraps the Request and Response, and provides some extra magic
that makes life a lot easier.

```perl
  use SCGI;
  use Web::App;

  my $scgi = SCGI.new(:port(8118));
  my $app = Web::App.new($scgi);

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
  }

  $app.run: $handler;

  ## End of script.
```

### Example 2

This example is using Web::App::Dispatch and some of its many rules.

```perl

  class RedirectHandler {
    has $.site;
    method handle ($context) {
      $context.redirect($.site);
    }
  }

  use SCGI;
  use Web::App::Dispatch;
  
  my $scgi = SCGI.new(:port(8118));
  my $app  = Web::App::Dispatch.new($scgi);

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

This is an example of using Web::Request and Web::Response together with
HTTP::Easy's PSGI adapter, without using Web::App as a wrapper.

```perl
  use HTTP::Easy::PSGI;
  use Web::Request;
  use Web::Response;

  my $http = HTTP::Easy::PSGI.new(); ## Default port is 8080.

  my $handler = sub (%env) {
    my $req = Web::Request.new(%env);
    my $res = Web::Response.new();
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

  * Finish testing framework, and write some tests.
  * Fix binary uploads. They need to use Buf instead of Str.
  * Add more pre-canned headers and automation to Web::Response.
    Sending files back to the client should be made easy.
  * Add more useful helpers to Web::App::Context.
  * I'm planning on refactoring Web::App::Dispatch into a collection of
    smaller components, with a more rubust routing system.

## Authors

 * [Timothy Totten](https://github.com/supernovus/) -- supernovus on #perl6
 * [Carl Mäsak](https://github.com/masak/) -- masak on #perl6

## License

Artistic License 2.0

