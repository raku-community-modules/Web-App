## WebRequest, pulled from ww6.
# A quick class to parse CGI-like stuff.
# A lot of this is based off of the November's CGI.pm
# With some Web.pm stuff thrown in for good measure.
#
# Coming soon: Optional support for PHP-like magic array variables.
# E.g.: <input name="people['male'][]['name']" value="Bob" />
# $this->get('people'); # { 'male' => [ { 'name' => 'Bob' } ] } 
# Oh, and multipart POST, including file uploads :-)

class WebRequest;

use Hash::Has;

## Note: env is a REQUIRED parameter in the new() declaration.

has $.body is rw;
has $.type is rw;
has $.method is rw;
has %.params is rw;
has %.cookies is rw;
has $.query is rw;
has $.userAgent is rw;
has $.remoteAddr is rw;
has $.debug is rw = 0;

submethod BUILD (:%env!) {

#    $*ERR.say: %env.perl;
#    $*ERR.say: %env.WHAT;

    my $cmdline = 0;

    # First, set the query string. Command line use allowed.
    if hash-has(%env, 'QUERY_STRING', :defined) {
        $.query = %env<QUERY_STRING>;
    }
    elsif defined @*ARGS[1] {
        $.query = @*ARGS[1..*].join("&");
        $cmdline = 1;
    }
    else {
        $.query = '';
    }

    # Now, parse the QUERY_STRING.
    self.parse_params($.query);

    if hash-has(%.params, 'DEBUG', :true) { $.debug = 1; }

    # Next up, a couple common items.
    $.type = hash-has(%env, 'CONTENT_TYPE', :true, :return) || '';
    $.method = hash-has(%env, 'REQUEST_METHOD', :true, :return) || 'GET';
    $.remoteAddr = hash-has(%env, 'REMOTE_ADDR', :true, :return) || '127.0.0.1';
    $.userAgent = hash-has(%env, 'HTTP_USER_AGENT', :true, :return) || 'unknown';

    if $cmdline && hash-has(%.params, 'FAKEPOST', :true) {
        $.method = 'POST';
        if %.params<FAKEPOST> eq '1' {
            $.type = 'application/x-www-form-urlencoded';
        }
        elsif %.params<FAKEPOST> eq '2' {
            $.type = 'multipart/form-data';
        }
        else {
            $.type = %.params<FAKEPOST>;
        }
    }

    # Now for POST requests.
    if $.method eq 'POST' {
        # First, build the body.
        if hash-has(%env, 'MODPERL6', :true) {
            say "Using mod_perl6." if $.debug;
            my $r = Apache::Requestrec.new();
            my $len = $r.read($.body, %env<CONTENT_LENGTH>);
        }
        elsif hash-has(%env, 'SCGI.Body', :defined) {
            say "Using SCGI interface" if $.debug;
            $.body = %env<SCGI.Body>;
        }
        else {
            say "Using standard CGI, slurping STDIN." if $.debug;
            $.body = $*IN.slurp;
        }

        # Now, check the type, and parse based on that.
        given $.type {
            when 'application/x-www-form-urlencoded' {
                say "Parsing urlencoded POST params." if $.debug;
                self.parse_params($.body);
            }
            when 'multipart/form-data' {
                say "Parsing multipart POST data." if $.debug;
                self.parse_multipart($.body);
            }
        }
    }

    # Now add cookies
    self.eat_cookie( %env<HTTP_COOKIE> ) if hash-has(%env, 'HTTP_COOKIE', :true);
}

method parse_params($string) {
    if $string ~~ / '=' | '&' | ';' / {
        my @params = $string.split(/ '&' | ';' /);
        for @params -> $param {
            my ($key, $value) = unescape($param).split('=', 2);
            if not defined $value { $value = ''; }
            self.add_param( $key, $value );
        }
    }
}

method eat_cookie(Str $http_cookie) {
    my @cookies = $http_cookie.split('; ');
    for @cookies -> $cookie {
        my ($key, $value) = unescape($cookie).split('=', 2);
        %.cookies{$key} = $value;
    }
}

# The following subs and methods were torn directly from November's CGI.pm
# All credit for them is given to the November team.

    sub unescape($string is copy) {
        $string .= subst('+', ' ', :g);
        # RAKUDO: This could also be rewritten as a single .subst :g call.
        #         ...when the semantics of .subst is revised to change $/,
        #         that is.
        # The percent_hack can be removed once the bug is fixed and :g is
        # added
        while $string ~~ / ( [ '%' <[0..9A..F]>**2 ]+ ) / {
            $string .= subst( ~$0,
            percent_hack_start( decode_urlencoded_utf8( ~$0 ) ) );
        }
        return percent_hack_end( $string );
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
            my $mask  = 0xFF;
            given @chars[0] {
                when { $^c +& 0xF0 == 0xF0 } { $bytes = 4; $mask = 0x07 }
                when { $^c +& 0xE0 == 0xE0 } { $bytes = 3; $mask = 0x0F }
                when { $^c +& 0xC0 == 0xC0 } { $bytes = 2; $mask = 0x1F }
            }
            my @shift = (^$bytes).reverse.map({6 * $_});
            my @mask  = $mask, 0x3F xx $bytes-1;
            $r ~= chr( [+] @chars.splice(0,$bytes) »+&« @mask »+<« @shift );
        }
        return $r;
    }

    method add_param ( Str $key, $value ) {
        # RAKUDO: синтаксис Hash :exists еще не реализован
        #        (Hash :exists{key} not implemented yet)
        # if %.params :exists{$key} {
        if %.params.exists($key) {
            # RAKUDO: ~~ Scalar
            if %.params{$key} ~~ Str | Int {
                my $old_param = %.params{$key};
                %!params{$key} = [ $old_param, $value ];
            }
            elsif %.params{$key} ~~ Array {
                %!params{$key}.push( $value );
            }
        }
        else {
            %!params{$key} = $value;
        }
    }

    method param ($key) {
       return %.params{$key};
    }

## End of November code.

## A simplified port of the get() method from Perlite::Config.

# Usage:  $request.get(:default("default value"), 'keyname', 'alternatekey');

method get (:$default, *@keys) {
    for @keys -> $key {
        if %.params.exists($key) {
            return %.params{$key};
        }
    }
    return $default;
}

method parse_multipart ($string) {
    ## TODO: Implement this
    say $.body;
}

