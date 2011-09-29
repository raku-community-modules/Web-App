class WWW::App::MethodHandler;
#
# A base class for WWW::App handlers that dispatch based on
# what methods exist. It can be used in a chain, and will 
# fall through if no matches are found. If you want to use it
# as the default handler, specify a :default method to be used
# if no other paths match.
#
# Very loosely based off of my older Lighter class from ww6.
#

has $.default = False; ## Override this if using as a default handler.

method handle ($req, $res, $rules) {
  my @parameters = $req.path.split('/').grep({ $_ !~~ /^$/});
  if (@parameters.elems > 0) {
    my $method = @parameters.shift;
    if self.can("handle_$method") {
      self."handle_$method"(:$req, :$res, :$rules, |@parameters);
      return True;
    }
  }
  if ($.default ~~ Str) {
    if self.can($.default) {
      self."{$.default}"(:$req, :$res, :$rules, |@parameters);
      return True;
    }
  }
  elsif ($.default ~~ Int) {
    $res.set-status: $.default;
    return True;
  }
  return False;
}

## End of class.