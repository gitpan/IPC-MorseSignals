#!/usr/bin/perl -T

use strict;
use warnings;

use POSIX qw/SIGINT SIGTERM SIGKILL EXIT_SUCCESS/;

use lib qw{blib/lib};

use IPC::MorseSignals qw/msend mrecv/;

my @res;

sub tryspeed {
 my ($l, $n) = @_;
 my $speed = 2 ** 16;
 my $ok = 0;
 my $desc;
 while ($speed && $ok < $n) {
  $desc = "$n sends of $l bytes at $speed bits/s";
  $speed /= 2;
  $ok = 0;
  print STDERR "try $desc";
TRY:
  for (1 .. $n) {
   print STDERR ".";
   my @alpha = ('a' .. 'z');
   my $msg = join '', map { $alpha[rand @alpha] } 1 .. $l;
   pipe my $rdr, my $wtr or die "$desc: pipe() failed : $!";
   my $pid = fork;
   if (!defined $pid) {
    die "$desc: fork() failed : $!";
   } elsif ($pid == 0) {
    close $rdr;
    local @SIG{qw/USR1 USR2/} = mrecv sub {
     print $wtr $_[0], "\n";
     close $wtr;
     exit EXIT_SUCCESS;
    };
    1 while 1;
   }
   close $wtr or die "$desc: close() failed : $!";
   eval {
    local $SIG{ALRM} = sub { die 'alarm' };
    my $a = (int(100 * (3 * $l) / $speed) || 1);
    $a = 10 if $a > 10;
    alarm $a;
    msend $msg => $pid, $speed;
    waitpid $pid, 0;
   };
   alarm 0;
   if ($@) {
    kill SIGINT,  $pid;
    kill SIGTERM, $pid;
    kill SIGKILL, $pid;
    close $rdr or die "$desc: close() failed : $!";
    print STDERR " timeout\n";
    next TRY;
   }
   my $recv = do { local $/; <$rdr> };
   close $rdr or die "$desc: close() failed : $!";
   if ($recv) {
    chomp $recv;
    if ($msg eq $recv) {
     ++$ok;
    } else {
     print STDERR " transfer error\n";
     last TRY;
    }
   } else {
    print STDERR " transfer failure\n";
    last TRY;
   }
  }
 }
 if ($speed) {
  print STDERR " OK\n\n";
  $desc = "$l bytes sent $n times";
  push @res, "$desc at $speed bits/s";
 }
}

tryspeed 4, 1;
tryspeed 4, 5;
tryspeed 4, 10;
tryspeed 4, 50;
tryspeed 16, 1;
tryspeed 16, 5;
tryspeed 16, 10;
tryspeed 64, 1;
tryspeed 64, 5;
tryspeed 64, 10;
tryspeed 256, 1;
tryspeed 256, 5;
tryspeed 1024, 1;

print STDERR "=== Summary ===\n";
print STDERR "$_\n" for @res;
