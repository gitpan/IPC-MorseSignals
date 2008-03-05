#!perl -T

use strict;
use warnings;

use utf8;

use Test::More tests => 3;

use lib 't/lib';
use IPC::MorseSignals::TestSuite qw/bench init cleanup/;

my $diag = sub { diag @_ };
my @res;

init 12;

ok(bench(4,  1, $diag, \@res));
ok(bench(4,  4, $diag, \@res));
ok(bench(16, 1, $diag, \@res));

cleanup;

diag '=== Summary ===';
diag $_ for sort {
 my ($l1, $n1) = $a =~ /(\d+)\D+(\d+)/;
 my ($l2, $n2) = $b =~ /(\d+)\D+(\d+)/;
 $l1 <=> $l2 || $n1 <=> $n2
} @res;
