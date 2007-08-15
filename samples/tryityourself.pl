#!/usr/bin/perl

use strict;
use warnings;

use lib qw!blib/lib!;

use IPC::MorseSignals qw/msend mrecv/;

my $pid = fork;
if (!defined $pid) {
 die "fork() failed : $!";
} elsif ($pid == 0) {
 local @SIG{qw/USR1 USR2/} = mrecv sub { print STDERR "recieved: $_[0]"; exit };
 print STDERR "child wait for data...\n";
 1 while 1;
}

msend "This message was sent with IPC::MorseSignals\n" => $pid, 1000;
waitpid $pid, 0;
