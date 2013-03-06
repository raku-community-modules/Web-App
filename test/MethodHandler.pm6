use v6;

## Looks for methods matching the first part of the path.
## So, if the path is /hello/world, this will look for a method
## called handle_hello() and if it's found, dispatch to it.
## It's a weak example of implementing something kinda like
## my Lighter plugin from ww6, but no where near as complex or functional.
##
## See the Web::App::MVC::Controllers::MethodDispatch role for a better
## implementation of this concept.
##

class MethodHandler {

  has $.default = False; ## Override this if using as a default handler.

  method handle ($context) {
    my @parameters = $context.path.split('/').grep({ $_ !~~ /^$/});
    if (@parameters.elems > 0) {
      my $method = @parameters.shift;
      if self.can("handle_$method") {
        self."handle_$method"($context, |@parameters);
        return True;
      }
    }
    if ($.default ~~ Str) {
      if self.can($.default) {
        self."{$.default}"($context, |@parameters);
        return True;
      }
    }
    elsif ($.default ~~ Int) {
      $context.set-status: $.default;
      return True;
    }
    return False;
  } ## /method handle

} ## /class MethodHandler
