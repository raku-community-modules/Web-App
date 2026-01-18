unit class Web::Request::File;

## Represents an uploaded file.

has $.formname;            ## The HTML form name.
has $.filename;            ## The filename for the upload.
has $.content-type is rw;  ## The plain value for Content-Type with no options.
has @.headers is rw;       ## The MIME headers.
has $.temppath;            ## Where we've stored the actual file.
has $.output;              ## Our IO object for output.
has $!wrote;               ## Set to the last line written.

constant $CRLF = "\x0D\x0A";

## We take the form name, and filename as our parameters.
method new($formname, $filename) {
    my $temppath = "/tmp/wrf-$formname-{time}.$*PID";
    my $output   = open($temppath, :w);
    self.bless(*, :$formname, :$filename, :$temppath, :$output)
}

## Delete the file.
method delete() {
    unlink($.temppath) if $.temppath && $.temppath.IO ~~ :f;
}

## Print to the file, with no newlines.
method print(*@lines) {
    with $!output {
        .print(|@lines);
        $!wrote = @lines.join;
    }
}

## Use "say" on the file.
method say (*@lines) {
    with $!output {
        .say(|@lines);
        $!wrote = @lines.join;
    }
}

## Print a string to the file.
## It will separate lines by CRLF, but only
## if there is more than one line to write.
## It's meant for use with Multipart, which splits
## by CRLF rather than LF.
method out($string) {
    self.print($CRLF) if $!wrote.defined && $!wrote !~~ /$CRLF$/;
    self.print($string)
}

## Close, close the output IO object, and return this.
method close() {
    with $!output {
        .close; ## Close the IO.
        $_ = Nil; ## Kill the IO.
    }
    self
}

## Return an open file for reading.
method get() {
    $.temppath && $.temppath.IO ~~ :f
      ?? open($.temppath, :r)
      !! Nil ## Sorry, nothing to return.
}

## Return the lines.
method lines() {
    if self.slurp -> $string {
        $string.lines
    }
    else {
        Nil
    }
}

## Return the content.
method slurp() {
    $.temppath && $.temppath.IO ~~ :f
      ?? $.temppath.slurp
      !! Nil
}

## Get a header if it exists.
## By default returns the text value from the first matching header.
## If you want all matching headers, add the :multiple flag.
## If you want options in addition to the text value, add the :opts flag.
## See Web::Request::Multipart::parse-mime-header() for the storage format.
method header($name, Bool :$multiple, Bool :$opts) {
    my @results;
    for @.headers -> $header {
        ## Headers are stored as a Pair.
        if $header.key ~~ $name { 
            my $result = $header.value;
            if $multiple {
                @results.push($opts ?? $result !! $result[0]);
            }
            else { ## A single value.
                return $opts ?? $result !! $result[0];
            }
        }
    }
    $multiple
      ?? @results
      !! Nil
}

method copy(Stringy $destination) {
    if $.temppath && $.temppath.IO ~~ :f {
        copy $.temppath, $destination;
    }
}

method move(Stringy $destination) {
    if $.temppath && $.temppath.IO ~~ :f {
        rename $.temppath, $destination;
    }
}

multi method raku(Web::Request::File:D:) {
    "Web::Request::File<$.filename>";
}

# vim: expandtab shiftwidth=4
