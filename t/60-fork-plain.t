#!perl -T

use strict;
use warnings;

use Test::More tests => 7;

use lib 't/lib';
use IPC::MorseSignals::TestSuite qw/try init cleanup/;

sub test {
 my ($desc, @args) = @_;
 eval { ok(try(@args), $desc) };
 fail($desc . " (died : $@)") if $@;
}

my @msgs = qw/hlagh hlaghlaghlagh HLAGH HLAGHLAGHLAGH \x{0dd0}\x{00}
              h\x{00}la\x{00}gh \x{00}\x{ff}\x{ff}\x{00}\x{00}\x{ff}/;

init 6;

test 'plain' => $_ for @msgs;

cleanup;

