class WWW::App;

use WWW::Request;
use WWW::Response;

has $.engine; ## The engine to handle requests.

method new ($engine) {
  return self.bless(*, :$engine);
}

method run (&app) {
  my $handler = sub (%env) {
    my $req = WWW::Request.new(%env);
    my $res = WWW::Response.new();
    app($req, $res); ## Call our method. We don't care what it returns.
    if (!$res.status) { $res.set-status(200); }
    return $res.response;
  }
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

