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

  use PSGI;

  has $.PSGI  = False;
  has $.P6SGI = True;
  has $.handler;

  method handle ($handler) {
    $!handler = $handler;
  }

  method request ($uri, :$method='GET', :$body) {

    my ($path, $query) = $uri.split('?', 2);
    $query //= '';

    my %env = (
      ## First standard HTTP variables.
      REQUEST_METHOD => $method,
      REQUEST_URI    => $uri,
      QUERY_STRING   => $query,
      PATH_INFO      => $path,
      SERVER_NAME    => 'localhost',
      SERVER_PORT    => 80,
    );

    populate-psgi-env(%env, :input($body), :errors($*ERR), 
      :p6sgi($.P6SGI), 
      :psgi-classic($.PSGI)
    );

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
