#!/usr/bin/perl -T

use strict;
use warnings;

use POSIX qw/SIGINT SIGTERM SIGKILL EXIT_SUCCESS EXIT_FAILURE WIFEXITED WEXITSTATUS/;

use lib qw{blib/lib};

use IPC::MorseSignals qw/msend mrecv/;

my @res;

sub tryspeed {
 my ($l, $n) = @_;
 my $speed = 2 ** 16;
 my $ok = 0;
 my $desc;
SPEED:
 while (($speed > 1) && ($ok < $n)) {
  $speed /= 2;
  $desc = "$n sends of $l bytes at $speed bits/s";
  $ok = 0;
  print STDERR "try $desc";
  for (1 .. $n) {
   print STDERR ".";
   my @alpha = ('a' .. 'z');
   my $msg = join '', map { $alpha[rand @alpha] } 1 .. $l;
   my $pid = fork;
   if (!defined $pid) {
    die "$desc: fork() failed : $!";
   } elsif ($pid == 0) {
    local @SIG{qw/USR1 USR2/} = mrecv sub {
     exit(($msg eq $_[0]) ? EXIT_SUCCESS : EXIT_FAILURE);
    };
    1 while 1;
    exit EXIT_FAILURE;
   }
   my $next = 0;
   eval {
    local $SIG{ALRM} = sub { die 'timeout' };
    my $a = (int(100 * (3 * $l) / $speed) || 1);
    $a = 10 if $a > 10;
    alarm $a;
    msend $msg => $pid, speed => $speed;
    waitpid $pid, 0;
    if (WIFEXITED($?) && (WEXITSTATUS($?) == EXIT_SUCCESS)) {
     ++$ok;
    } else {
     print STDERR " transfer error\n";
     $next = 1;
    }
   };
   alarm 0;
   if ($@) {
    kill SIGINT,  $pid;
    kill SIGTERM, $pid;
    kill SIGKILL, $pid;
    print STDERR " timeout\n";
    $next = 1;
   }
   next SPEED if $next;
  }
 }
 $desc = "$l bytes sent $n times";
 if ($speed >= 1) {
  print STDERR " OK\n\n";
  push @res, "$desc at $speed bits/s";
 } else {
  print STDERR " FAILED\n\n";
  push @res, "$desc FAILED";
 }
}

tryspeed 4, 1;
tryspeed 4, 4;
tryspeed 4, 16;
tryspeed 4, 64;
tryspeed 4, 256;
tryspeed 16, 1;
tryspeed 16, 4;
tryspeed 16, 16;
tryspeed 16, 64;
tryspeed 64, 1;
tryspeed 64, 4;
tryspeed 64, 16;
tryspeed 256, 1;
tryspeed 256, 4;
tryspeed 1024, 1;

print STDERR "=== Summary ===\n";
print STDERR "$_\n" for @res;
