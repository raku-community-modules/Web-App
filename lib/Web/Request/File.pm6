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
method new ($formname!, $filename!) {
  my $temppath = "/tmp/wrf-$formname-{time}.$*PID";
  my $output   = open($temppath, :w);
  return self.bless(*, :$formname, :$filename, :$temppath, :$output);
}

## Delete the file.
method delete {
  if $.temppath && $.temppath.IO ~~ :f {
    unlink($.temppath);
  }
}

## Print to the file, with no newlines.
method print (*@lines) {
  if defined $!output {
    $!output.print(|@lines);
    $!wrote = @lines.join;
  }
}

## Use "say" on the file.
method say (*@lines) {
  if defined $!output {
    $!output.say(|@lines);
    $!wrote = @lines.join;
  }
}

## Print a string to the file.
## It will separate lines by CRLF, but only
## if there is more than one line to write.
## It's meant for use with Multipart, which splits
## by CRLF rather than LF.
method out ($string) {
  if defined $!wrote && $!wrote !~~ /$CRLF$/ {
    self.print($CRLF);
  }
  self.print($string);
}

## Close, close the output IO object, and return this.
method close {
  if defined $!output {
    $!output.close; ## Close the IO.
    $!output = Nil; ## Kill the IO.
  }
  return self;
}

## Return an open file for reading.
method get {
  if $.temppath && $.temppath.IO ~~ :f {
    return open($.temppath, :r);
  }
  return; ## Sorry, nothing to return.
}

## Return the lines.
method lines {
  my $string = self.slurp;
  if $string {
    return $string.lines;
  }
  return;
}

## Return the content.
method slurp {
  if $.temppath && $.temppath.IO ~~ :f {
    return slurp($.temppath);
  }
  return;
}

## Get a header if it exists.
## By default returns the text value from the first matching header.
## If you want all matching headers, add the :multiple flag.
## If you want options in addition to the text value, add the :opts flag.
## See Web::Request::Multipart::parse-mime-header() for the storage format.
method header ($name, Bool :$multiple, Bool :$opts) {
  my @results;
  for @.headers -> $header {
    ## Headers are stored as a Pair.
    if $header.key ~~ $name { 
      my $result = $header.value;
      if $multiple {
        if $opts {
          @results.push($result);
        }
        else {
          @results.push($result[0]);
        }
      }
      else { ## A single value.
        if $opts { return $result; }
        else { return $result[0]; }
      }
    }
  }
  if $multiple {
    return @results;
  }
  else {
    return Nil;
  }
}

method copy (Stringy $destination) {
  ## This should really use the IO.copy function/method.
  ## But, it's currently not implemented in Rakudo nom.
  ## So, this is a temporary workaround.
  ## Based on the File::Copy lib formerly in perl6-File-Tools by tadzik.
  if $.temppath && $.temppath.IO ~~ :f {
    my $from = open($.temppath,   :r, :bin);
    my $to   = open($destination, :w, :bin);
    $to.write($from.read(4096)) until $from.eof;
    $from.close;
    $to.close;
  }
}

method move (Stringy $destination) {
  ## This is as big of a hack as copy, and in fact, uses it.
  ## There should be a move/rename command in Rakudo's IO, so this is
  ## a temporary workaround.
  self.copy($destination); ## Copy to the new location.
  self.delete;             ## Now delete!
}

method perl {
  return "Web::Request::File<$.filename>";
}

