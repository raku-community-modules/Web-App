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

method say (Str $text) {
  @.body.push: $text~"\x0D\x0A"; ## Use CRLF.
}

method print (Str $text) {
  @.body.push: $text;
}

method insert (Str $text) {
  @.body.unshift: $text;
}

method response {
  return [ $.status, @.headers, @.body ];
}
