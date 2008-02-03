#!/usr/bin/perl -T

use strict;
use warnings;

use POSIX qw/SIGINT SIGTERM SIGKILL SIGHUP EXIT_FAILURE/;

use lib qw{blib/lib};

use IPC::MorseSignals qw/msend mrecv mreset/;

my $lives = 100;

sub spawn {
 --$lives;
 die 'forked too many times' if $lives < 0;
 pipe my $rdr, my $wtr or die "pipe() failed: $!";
 my $pid = fork;
 if (!defined $pid) {
  die "fork() failed: $!";
 } elsif ($pid == 0) {
  local %SIG;
  close $rdr or die "close() failed: $!";
  select $wtr;
  $| = 1;
  my $rcv = mrecv %SIG, cb => sub { print $wtr $_[1], "\n" };
  my $ppid = getppid;
  $SIG{ALRM} = sub { alarm 1; kill SIGHUP => $ppid };
  alarm 1;
  $SIG{HUP}  = sub { alarm 0; mreset $rcv };
  1 while 1;
  exit EXIT_FAILURE;
 }
 my $ready = 0;
 local $SIG{HUP} = sub { $ready = 1 };
 sleep 1 until $ready;
 close $wtr or die "close() failed: $!";
 my $oldfh = select $rdr;
 $| = 1;
 select $oldfh;
 return ($pid, $rdr);
}  

sub slaughter {
 my ($pid, $rdr) = @_;
 if (defined $rdr) {
  close $rdr or die "close() failed: $!";
 }
 if (defined $pid) {
  kill SIGINT  => $pid;
  kill SIGTERM => $pid;
  kill SIGKILL => $pid;
  waitpid $pid, 0;
 }
}  

my @res;

my ($pid, $rdr) = spawn;

sub tryspeed {  
 my ($l, $n) = @_;
 my $speed = 2 ** 16;
 my $ok = 0;
 my @alpha = ('a' .. 'z');
 my $msg = join '', map { $alpha[rand @alpha] } 1 .. $l;
 while (($ok < $n) && (($speed /= 2) >= 1)) {
  print STDERR "$n sends of $l bytes at $speed bits/s";
TRY:
  for (1 .. $n) {
   print STDERR '.';
   my $r = '';
   eval {
    local $SIG{ALRM} = sub { print STDERR "timeout\n"; die };
    my $a = (int(100 * (3 * $l) / $speed) || 1);
    $a = 10 if $a > 10;
    alarm $a;
    msend $msg => $pid, speed => $speed;
    $r = <$rdr>;
   };
   kill SIGHUP => $pid if $@;
   alarm 0;
   if (!defined $r) { # Something bad happened, respawn
    print STDERR "oops\n";
    slaughter $pid, $rdr;
    ($pid, $rdr) = spawn;
    redo TRY;         # Retry this send
   } else {
    chomp $r;
    if ($r eq $msg) {
     ++$ok;
    } else {
     print STDERR "transfer error\n";
     kill SIGHUP => $pid;
     last TRY;
    }
   }
  }
 }
 my $desc = "$l bytes sent $n times";
 if ($speed >= 1) {
  print STDERR " OK\n\n";
  push @res, "$desc at $speed bits/s";
 } else {
  print STDERR " FAILED\n\n";
  push @res, "$desc FAILED";
 }
}

tryspeed 4,    1;
tryspeed 4,    4;
tryspeed 4,    16;
tryspeed 4,    64;
tryspeed 4,    256;
tryspeed 16,   1;
tryspeed 16,   4;
tryspeed 16,   16;
tryspeed 16,   64;
tryspeed 64,   1;
tryspeed 64,   4;
tryspeed 64,   16;
tryspeed 256,  1;
tryspeed 256,  4;
tryspeed 1024, 1;

print STDERR "=== Summary ===\n";
print STDERR "$_\n" for @res;
