#!/usr/bin/env perl

use strict;
use warnings;

use POSIX qw/SIGINT SIGTERM SIGKILL SIGHUP EXIT_FAILURE/;

use lib qw{blib/lib t/lib};

use IPC::MorseSignals::TestSuite qw/init bench cleanup/;

my $diag = sub { print STDERR "@_\n" };
my @res;

init 100;

bench 4,    1,   $diag, \@res;
bench 4,    4,   $diag, \@res;
bench 4,    16,  $diag, \@res;
bench 4,    64,  $diag, \@res;
bench 4,    256, $diag, \@res;
bench 16,   1,   $diag, \@res;
bench 16,   4,   $diag, \@res;
bench 16,   16,  $diag, \@res;
bench 16,   64,  $diag, \@res;
bench 64,   1,   $diag, \@res;
bench 64,   4,   $diag, \@res;
bench 64,   16,  $diag, \@res;
bench 256,  1,   $diag, \@res;
bench 256,  4,   $diag, \@res;
bench 1024, 1,   $diag, \@res;

cleanup;

print STDERR "=== Summary ===\n";
print STDERR "$_\n" for @res;
