#!perl -T

use strict;
use warnings;

use utf8;

use Test::More tests => 8;

use lib 't/lib';
use IPC::MorseSignals::TestSuite qw/try init cleanup/;

sub test {
 my ($desc, @args) = @_;
 eval { ok(try(@args), $desc) };
 fail($desc . " (died : $@)") if $@;
}

my @msgs = (
 \(undef, -273, 1.1, 'yes', '¥€$'),
 [ 5, 6 ],
 { hlagh => 1, HLAGH => 2 },
 { x => -3.573 },
);
$msgs[7]->{y} = $msgs[7];

init 6;

for (0 .. $#msgs) {
 test 'storable ' . $_ => $msgs[$_];
}

cleanup;

