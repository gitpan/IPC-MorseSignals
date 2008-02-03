#!perl -T

use strict;
use warnings;

use Test::More tests => 4;

use lib 't/lib';
use IPC::MorseSignals::TestSuite qw/try init cleanup/;

sub test {
 my ($desc, @args) = @_;
 eval { ok(try(@args), $desc) };
 fail($desc . " (died : $@)") if $@;
}

init 12;

test 'ascii'          => 'hello';
test 'few bits'       => "\0" x 5;
test 'lots of bits'   => "\x{FF}" x 5;
test 'null character' => "a\0b";

cleanup;
