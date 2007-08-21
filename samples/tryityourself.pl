#!/usr/bin/perl

use strict;
use warnings;

use lib qw!blib/lib!;

use IPC::MorseSignals qw/msend mrecv/;

my $pid = fork;
if (!defined $pid) {
 die "fork() failed : $!";
} elsif ($pid == 0) {
 my $s = mrecv local %SIG, cb => sub {
  print STDERR "I, the child, recieved this from $_[0]: $_[1]\n";
  exit
 };
 print STDERR "I'm $$ (the child), and I'm waiting for data...\n";
 1 while 1;
}

print STDERR "I'm $$ (the father), and I'm gonna send a message to my child $pid.\n";

msend "This message was sent with IPC::MorseSignals" => $pid;
waitpid $pid, 0;
