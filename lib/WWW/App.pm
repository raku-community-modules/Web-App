class WWW::App;

use WWW::Request;
use WWW::Response;
use SCGI; ## This should eventually be a require call.

has $.engine; ## The engine to handle requests. Must support handle().

method new (:$SCGI, :$CGI, :$FastCGI, :$mod_perl6, :$debug) {
  my $engine;
  my $strict = True;
  if ($debug) { $strict = False; }
  if ($SCGI) {
    $engine = SCGI.new(:port($SCGI), :PSGI, :$strict, :$debug);
  }
  else { die "Sorry, that engine is not yet supported."; }
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
  $!engine.handle: $handler;
}
