use v6.c;
use lib 'lib';

use Test;

plan 8;

use-ok 'Web::App';
use-ok 'Web::App::Context';
use-ok 'Web::App::Dispatch';
use-ok 'Web::App::Test';
use-ok 'Web::Request';
use-ok 'Web::Request::File';
use-ok 'Web::Request::Multipart';
use-ok 'Web::Response';

