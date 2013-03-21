## A PSGI adapter that is used in tests.
## It's not a persistent daemon, but instead allows you to create
## fake requests, and test the results of those requests.
##
## Usage:
##
##  my $test = Web::App::Test.new;
##  my $app  = Web::App.new($test);
##  $app.run(sub ($c) { my $name = $c.path; return "hello $name" });
##  my @return = $test.request("/uri");
##  is @return[0], '200', 'request returned proper status code';
##  is @return[2][0], 'hello /uri', 'request returned proper content';
##
## Or use Web::App::Dispatch or another derived framework as your $app.
## Either way, the $test.request() method can be used to simulate
## PSGI requests to the application.
##

class Web::App::Test {

  has $.handler;

  method handle ($handler) {
    $!handler = $handler;
  }

  method request ($uri, :$method='GET', :$body) {

    my ($path, $query) = $uri.split('?', 2);
    $query //= '';

    my %env = {
      ## First standard HTTP variables.
      REQUEST_METHOD => $method,
      REQUEST_URI    => $uri,
      QUERY_STRING   => $query,
      PATH_INFO      => $path,
      SERVER_NAME    => 'localhost',
      SERVER_PORT    => 80,
      ## Now the PSGI variables.
      'psgi.version'      => [1,0],
      'psgi.url_schema'   => 'http',
      'psgi.multithread'  => False,
      'psgi.multiprocess' => False,
      'psgi.input'        => $body,
      'psgi.errors'       => $*ERR,
      'psgi.run_once'     => False,
      'psgi.nonblocking'  => False,
      'psgi.streaming'    => False,
    };

    if $!handler ~~ Callable {
      return $!handler(%env);
    }
    elsif $!handler.can('handle') {
      return $!handler.handle(%env);
    }
    else {
      return Nil;
    }
  }

}
