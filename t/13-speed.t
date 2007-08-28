#!perl -T

use strict;
use warnings;

use Test::More tests => 3;

use lib 't/lib';
use IPCMTest qw/speed init cleanup/;

my $diag = sub { diag @_ };
my @res;

init;

ok(speed(4,  1, $diag, \@res));
ok(speed(4,  4, $diag, \@res));
ok(speed(16, 1, $diag, \@res));

cleanup;

diag '=== Summary ===';
diag $_ for sort {
 my ($l1, $n1) = $a =~ /(\d+)\D+(\d+)/;
 my ($l2, $n2) = $b =~ /(\d+)\D+(\d+)/;
 $l1 <=> $l2 || $n1 <=> $n2
} @res;
