class WWW::Response;

has $.status is rw;
has @.headers;
has @.body;

method set-status (Int $status) {
  if ($status < 100 || $status > 599) { die "invalid HTTP status code."; }
  $.status = $status;
}

method content-type (Str $type) {
  self.add-header('Content-Type' => $type);
}

method add-header (Pair $header) {
  @.headers.push: $header;
}

method insert-header (Pair $header) {
  @.headers.unshift: $header;
}

method say (Str $text) {
  @.body.push: $text~"\n";
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
