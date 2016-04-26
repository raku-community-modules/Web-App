use v6;

unit class Web::Request::Multipart;

use Web::Request::File;

## Represents a MIME multipart section we are parsing.

has $.boundary;                   ## Must be set during object creation.
has @.parts;                      ## The actual parts we've found.
has @!headers;                    ## Found headers. Files save these.
has $.formid     is rw;           ## Set to the current form id.
has $!file;                       ## Set to a Web::Request::File object.
has $!nest;                       ## Used if we find a nested multipart.
has $!value            = '';      ## Set to the content if we are a form-field.
has $!in-headers       = True;    ## True When parsing headers.
has $.done       is rw = False;   ## Set to true when parsing is complete.

## Take a MIME header and split it into value and options.
## Returns a Pair, where the key is the name of the header,
## and the value is an array, the first element of which is the
## value of the header, and the second element of which is a hash
## of any settings of the header.
## i.e., given the header:
##  Content-Disposition: form-data; name="files"; filename="file1.txt"
## It would return:
##   "Content-Disposition" => 
##     [ "form-data", { "name" => "files", "filename" => "file1.txt" } ];
##
method parse-mime-header (Str $header) {
  my ($name, $values) = $header.split(': ', 2);
  my ($value, @opts)  = $values.split(/';'\s*/);
  my $opts = {};
  for @opts -> $opt {
    my ($key, $val) = $opt.split('=', 2);
    $val ~~ s/^'"'//; ## Strip off leading " mark.
    $val ~~ s/'"'$//; ## Strip off following " mark.
    $opts{$key} = $val;
  }
  return $name => [ $value, $opts ];
}

## Parse one of our lines.
method parse-line (Stringy $line) {
  if $line ~~ / ^ '--' {$.boundary} / { ## Beginning/End of a part.
    if defined $!file {
      $!file.headers = @!headers;
      @.parts.push: $!file.close; ## Close the file.
    }
    elsif $.formid && $!value {
      @.parts.push: $.formid => $!value;
    }
    $!in-headers = True;
    $!file       = Nil;
    $!value      = '';
    $!nest       = Nil;
    @!headers    = Nil;
    if $line ~~ / '--' $ / { ## The final boundary.
      $.done = True;
    }
  }
  elsif $!in-headers && $line eq '' { ## A blank line ends headers.
    $!in-headers = False;
    if $!nest { 
      my $nested = Web::Request::Multipart.new(:boundary($!nest), :$.formid);
      return $nested; ## Send the nested Multipart back for processing.
    }
  }
  elsif $!in-headers {
    my $header = self.parse-mime-header($line);
    @!headers.push: $header;
    if $header.key.lc eq 'content-disposition' {
      if ($header.value[1]<name>:exists) {
        $.formid = $header.value[1]<name>;
      }
      if ($header.value[1]<filename>:exists) {
        ## Let's create a file object.
        $!file = Web::Request::File.new(
          $.formid,                      ## The form name.
          $header.value[1]<filename>     ## the filename
        );
      }
    }
    elsif $header.key.lc eq 'content-type' 
    && $header.value[0].lc ~~ /^ multipart/  ## :i not working?
    && ($header.value[1]<boundary>:exists) {
      $!nest = $header.value[1]<boundary>; ## Nested boundary.
    }
  }
  else {
    if $!file {
      $!file.out($line);  ## Output the line, with CRLF if needed.
    }
    else {
      $.value ~= $line;   ## Add to our own value.
    }
  }
  return; ## By default we return nothing.
}

