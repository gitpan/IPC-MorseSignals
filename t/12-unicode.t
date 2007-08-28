#!perl -T

use strict;
use warnings;

use Test::More tests => 7;

use utf8;

use lib 't/lib';
use IPCMTest qw/try init cleanup/;

init 1;

ok(try('hello'), 'ascii');
ok(try("\0" x 5), 'few bits');
ok(try("\x{FF}" x 5), 'lots of bits');
ok(try("a\0b"), 'null character');
ok(try('éàùçà'), 'extended');
ok(try('€€€'), 'unicode');
ok(try('à€béd'), 'mixed');

cleanup;
