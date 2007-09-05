#!perl -T

use strict;
use warnings;

use Test::More tests => 2;

use lib 't/lib';
use IPCMTest qw/try init cleanup/;

sub test {
 my ($desc, @args) = @_;
 eval { ok(try(@args), $desc) };
 fail($desc . " (died : $@)") if $@;
}

init 6;

test 'anonymous' => 'x', 0;
test 'signed'    => 'x', 1;

cleanup;
