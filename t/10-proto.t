#!perl -T

use strict;
use warnings;

use Test::More tests => 2;

use lib 't/lib';
use IPCMTest qw/try init cleanup/;

init;

ok(try('x', 0), 'anonymous');
ok(try('x', 1), 'signed');

cleanup;
