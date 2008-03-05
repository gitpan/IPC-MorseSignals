#!perl -T

use strict;
use warnings;

use utf8;

use Test::More tests => 5;

use lib 't/lib';
use IPC::MorseSignals::TestSuite qw/try init cleanup/;

sub test {
 my ($desc, @args) = @_;
 eval { ok(try(@args), $desc) };
 fail($desc . " (died : $@)") if $@;
}

my @msgs = qw/€éèë 月語 x tata たTÂ/;

init 6;

test 'plain' => $_ for @msgs;

cleanup;

