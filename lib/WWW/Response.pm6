class WWW::Response;

has $.status is rw;
has @.headers;
has @.body;

method set-status (Int $status) {
  if ($status < 100 || $status > 599) { die "invalid HTTP status code."; }
  $.status = $status;
}

method content-type (Str $type?) {
  if ($type) {
    self.add-header('Content-Type' => $type);
  }
  else {
    for @.headers -> $header {
      if ($header.key.lc eq 'content-type') {
        return $header.value;
      }
    }
    return;
  }
}

method redirect (Str $url, $status=302) {
  self.set-status($status);
  self.add-header('Location' => $url);
}

method add-header (Pair $header) {
  @.headers.push: $header;
}

method insert-header (Pair $header) {
  @.headers.unshift: $header;
}

method send (Stringy $text) {
  @.body.push: $text;
}

method insert (Stringy $text) {
  @.body.unshift: $text;
}

method send-file (Str $filename, :$file, :$content, :$type='application/octet-stream', Bool :$cache) {
  if ! $file && ! $content {
    die "You must specify either a :file or :contents parameter.";
  }
  self.content-type("$type; name=\"$filename\"");
  my $disp = "inline; filename=\"$filename\"";
  self.add-header('Content-Disposition' => $disp);
  if ! $cache {
    self.add-header('Cache-Control' => 'no-cache');
  }
  my $contents;
  if $file {
    $contents = slurp($file);
  }
  elsif $content {
    $contents = $content;
  }
  self.send($contents);
}

method response {
  my $headers = @.headers;
  my $body    = @.body;
  return [ $.status, $headers, $body ];
}

