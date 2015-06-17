unit class Web::Request;

use Web::Request::Multipart; ## Multipart context parsers.
use Web::Request::File;      ## Uploaded files.

## Based on my old WebRequest class, which itself was based on the CGI.pm
## from the November project as well as Web::Request from the Web project.

## TODO: Better handling of multipart encoding.

has $.body;
has $.type;
has $.method;
has $.host;
has $.remote-address;
has $.remote-host;
has $.script-name;
has $.path;
has $.uri;
has $.port;
has $.proto;
has $.query-string;
has $.content-length;
has $.user-agent;
has %.env;
has %.params;
has %.cookies;
has %.files;   ## Indexed by the formid.

constant $CRLF = "\x0D\x0A";

method new(%env) {
  my %new = %( 'env' => %env );
  ## First, find out if we have a query string.
  if defined %env<QUERY_STRING> { %new<query-string> = %env<QUERY_STRING>; }
  else { %new<query-string> = ''; }
  ## Now, let's add some common stuff.
  %new<type> = %env<CONTENT_TYPE> // '';
  %new<method> = %env<REQUEST_METHOD> // 'GET';
  %new<host> = %env<HTTP_HOST> // %env<SERVER_NAME> //  %env<HOSTNAME> // 'localhost';
  %new<remote-address> = %env<REMOTE_ADDRESS> // '';
  %new<user-agent> = %env<HTTP_USER_AGENT> // 'unknown';
  %new<uri> = %env<REQUEST_URI> // '';
  %new<path> = %env<PATH_INFO> // %new<uri>;
  %new<script-name> = %env<SCRIPT_NAME> // '';
  %new<port> = %env<SERVER_PORT> ?? +%env<SERVER_PORT> !! 80;
  %new<proto> = %env<HTTPS> ?? 'https' !! 'http';
  %new<content-length> = %env<CONTENT_LENGTH> ?? +%env<CONTENT_LENGTH> !! 0;
  %new<remote-host> = %env<REMOTE_HOST> // %new<remote-address>;
  ## Now, if we're POST or PUT, let's get the body.
  if %new<method> eq 'POST' | 'PUT' {
    ## First try for PSGI-compliant input.
    if %env<psgi.input>:exists {
      ## PSGI input can be a Buf, Str(ing), Array or IO object.
      my $input = %env<psgi.input>;
      if $input ~~ Buf && %new<type> eq 
        'application/x-www-form-urlencoded' | 'multipart/form-data'
      {
        $input .= decode;
      }

      if $input ~~ Str | Buf {
        %new<body> = $input;
      }
      elsif $input ~~ Array {
        %new<body> = $input.join($CRLF); ## Join with CRLF.
      }
      elsif $input ~~ IO {
        %new<body> = $input.slurp;
      }
    }
    ## Fallbacks for non-PSGI connectors.
    elsif %env.exists('MODPERL6') {
      my $body;
      my $r = Apache::Requestrec.new();
      my $len = $r.read($body, %env<CONTENT_LENGTH>);
      %new<body> = $body;
    }
    elsif %env.exists('scgi.request') {
      %new<body> = %env<scgi.request>.input;
    }
    elsif %env.exists('fastcgi.request') {
      %new<body> = %env<fastcgi.request>.input;
    }
    ## Last resort fallback for standard CGI.
    else {
      %new<body> = $*IN.slurp;
    }
  }
  return self.bless(*, |%new)!initialize();
}

method !initialize {
  ## First, let's parse our query string arguments.
  if $.query-string {
    self.parse-params($.query-string);
  }
  ## Now, let's parse our POST/PUT arguments.
  if $.method eq 'POST' | 'PUT' {
    given $.type {
      when 'application/x-www-form-urlencoded' {
        self.parse-params($.body);
      }
      when /^ 'multipart/form-data' / {
        my $boundary;
        if $.type ~~ /'boundary='(.*)$/ {
          $boundary = $0.Str;
        }
        else {
          warn "No multipart boundary found, could not continue";
          return;
        }
        self.parse-multipart($.body, $boundary);
      }
    }
  }
  ## Finally, add the cookies.
  if %.env<HTTP_COOKIE> {
    self.eat-cookie(%.env<HTTP_COOKIE>);
  }
  return self;
}

method parse-params(Str $string) {
  if $string ~~ / '=' | '&' | ';' / {
    my @params = $string.split(/ '&' | ';' /);
    for @params -> $param {
      my ($key, $value) = unescape($param).split('=', 2);
      if not defined $value { $value = ''; }
      self.add-param($key, $value);
    }
  }
}

method eat-cookie(Str $http_cookie) {
  my @cookies = $http_cookie.split('; ');
  for @cookies -> $cookie {
    my ($key, $value) = unescape($cookie).split('=', 2);
    %.cookies{$key} = $value;
  }
}

sub unescape($string is copy) {
  $string ~~ s:g/'+'/ /;
  while $string ~~ / ( [ '%' <[0..9A..F]>**2 ]+ ) / {
    $string .= subst( $0.Str,
      percent_hack_start(decode_urlencoded_utf8($0.Str))
    );
  }
  return percent_hack_end($string);
}

sub percent_hack_start($str is rw) {
  if $str ~~ '%' {
    $str = '___PERCENT_HACK___';
  }
  return $str;
}

sub percent_hack_end($str) {
  return $str.subst('___PERCENT_HACK___', '%', :g);
}

sub decode_urlencoded_utf8($str) {
  my $r = '';
  my @chars = map { :16($_) }, $str.split('%').grep({$^w});
  while @chars {
    my $bytes = 1;
    my $mask = 0xFF;
    given @chars[0] {
      when { $^c +& 0xF0 == 0xF0 } { $bytes = 4; $mask = 0x07; }
      when { $^c +& 0xE0 == 0xE0 } { $bytes = 3; $mask = 0x0F; }
      when { $^c +& 0xC0 == 0xC0 } { $bytes = 2; $mask = 0x1F; }
    }
    my @shift = (^$bytes).reverse.map({6 * $_});
    my @mask  = $mask, 0x3f xx $bytes-1;
    $r ~= chr( [+] @chars.splice(0, $bytes) »+&« @mask »+<« @shift );
  }
  return $r;
}

method add-param (Str $key, $value, Bool :$files) {
  my $params;
  if ($files) { $params = %.files; }
  else        { $params = %.params; }
  if $params{$key}:exists {
    if $params{$key} ~~ Array {
      $params{$key}.push($value);
    }
    else {
      my $old_param = $params{$key};
      $params{$key} = [ $old_param, $value ];
    }
  }
  else {
    $params{$key} = $value;
  }
}

method add-file (Web::Request::File $file) {
  return self.add-param($file.formname, $file, :files);
}

method param ($key) {
  return %.params{$key};
}

## Look for parameters, return first one found, or optional default value.
##   $request.get(:default("world"), 'hello', 'hi', howdy');
## By default if the field had more than one value passed, only the first
## value is returned. If you want all, specify the :multiple option.
method get (Stringy :$default, Bool :$multiple, *@keys) {
  for @keys -> $key {
    if %.params{$key.Str}:exists {
      my $return = %.params{$key};
      if (! $multiple) && $return ~~ Array {
        return $return[0];
      }
      return $return;
    }
  }
  return $default;
}

## Get a file by it's upload field id.
## By default it will return only the first
## file found for the given upload field.
## Pass the :multiple option if you want multiples.
method file (Stringy $field, Bool :$multiple) {
  if %.files{$field}:exists {
    my $file = %.files{$field};
    if (! $multiple) && $file ~~ Array {
      return $file[0];
    }
    return $file;
  }
  return Nil; ## Nothing found, sorry.
}

## Parse multipart/form-data.
method parse-multipart (Str $string, Str $boundary) {
  my @content = $string.split($CRLF);
  my @context = Web::Request::Multipart.new(:$boundary);
  for @content -> $line {
    if @context {
      my $context = @context[0];
      my $parse = $context.parse-line($line);
      if $parse ~~ Web::Request::Multipart {
        @context.unshift: $parse;
      }
      elsif $context.done {
        for $context.parts -> $part {
          if $part ~~ Web::Request::File {
            self.add-file($part);
          }
          elsif $part ~~ Pair {
            self.add-param($part.key, $part.value);
          }
        }
        @context.shift; 
      }
    }
  }
}

