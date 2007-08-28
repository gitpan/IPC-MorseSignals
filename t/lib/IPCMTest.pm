package IPCMTest;

use strict;
use warnings;

use POSIX qw/SIGINT SIGTERM SIGKILL SIGHUP EXIT_FAILURE/;

use IPC::MorseSignals qw/msend mrecv mreset/;

use base qw/Exporter/;

our @EXPORT_OK = qw/try speed init cleanup/;

our $lives = 10;

my ($utf8, $pid, $rdr);

sub spawn {
 --$lives;
 die 'forked too many times' if $lives < 0;
 pipe $rdr, my $wtr or die "pipe() failed: $!";
 $pid = fork;
 if (!defined $pid) {
  die "fork() failed: $!";
 } elsif ($pid == 0) {
  close $rdr or die "close() failed: $!";
  binmode $wtr, ':utf8' if $utf8;
  my $block = 0;
  my $rcv = mrecv local %SIG, cb => sub {
   if ($block) {
    $block = 0;
   } else {
    select $wtr; $| = 1;
    print $wtr $_[0], ':', $_[1], "\n";
    select $wtr; $| = 1;
   }
  };
  $SIG{HUP} = sub { mreset $rcv };
  $SIG{__WARN__} = sub { $block = 1 };
  1 while 1;
  exit EXIT_FAILURE;
 }
 close $wtr or die "close() failed: $!";
 binmode $rdr, ':utf8' if $utf8;
}

sub slaughter {
 kill SIGINT  => $pid;
 kill SIGTERM => $pid;
 kill SIGKILL => $pid;
 waitpid $pid, 0;
}

sub init {
 $utf8 = $_[0] || 0;
 spawn;
}

sub cleanup { slaughter }

sub try {
 my ($msg, $sign) = @_;
 $sign ||= 0;
 my $speed = 2 ** 16;
 my $ok = 0;
 my @ret;
 while (!$ok && (($speed /= 2) >= 1)) {
  my $r = '';
  eval {
   local $SIG{ALRM} = sub { die 'timeout' };
   local $SIG{__WARN__} = sub { die 'do not want warnings' };
   my $a = (int(100 * (3 * length $msg) / $speed) || 1);
   $a = 10 if $a > 10;
   alarm $a;
   kill SIGHUP => $pid;
   msend $msg => $pid, speed => $speed, utf8 => $utf8, sign => $sign;
   $r = <$rdr>;
  };
  kill SIGHUP => $pid if $@;
  alarm 0;
  if (!defined $r) { # Something bad happened, respawn
   close $rdr or die "close() failed: $!";
   slaughter;
   spawn;
   $speed *= 2;      # Retry this speed
  } else {
   chomp $r;
   if ($r eq ((($sign) ? $$ : 0) . ':' . $msg)) {
    $ok = 1;
   } else {
    kill SIGHUP => $pid;
   }
  }
 }
 return ($ok) ? $speed : 0;
}

sub speed {
 my ($l, $n, $diag, $res) = @_;
 my $speed = 2 ** 16;
 my $ok = 0;
 my @alpha = ('a' .. 'z');
 my $msg = join '', map { $alpha[rand @alpha] } 1 .. $l;
 my $desc_base = "$l bytes sent $n times";
 while (($ok < $n) && (($speed /= 2) >= 1)) {
  my $desc = "$desc_base at $speed bits/s";
  $diag->("try $desc...");
TRY:
  for (1 .. $n) {
   my $r = '';
   eval {
    local $SIG{ALRM} = sub { die 'timeout' };
    local $SIG{__WARN__} = sub { die 'do not want warnings' };
    my $a = (int(100 * (3 * $l) / $speed) || 1);
    $a = 10 if $a > 10;
    alarm $a;
    kill SIGHUP => $pid;
    msend $msg => $pid, speed => $speed, utf8 => $utf8, sign => 0;
    $r = <$rdr>;
   };
   kill SIGHUP => $pid if $@;
   alarm 0;
   if (!defined $r) { # Something bad happened, respawn
    close $rdr or die "close() failed: $!";
    slaughter;
    spawn;
    redo TRY;         # Retry this send
   } else {
    chomp $r;
    if ($r eq '0:' . $msg) {
     ++$ok;
    } else {
     kill SIGHUP => $pid;
     last TRY;
    }
   }
  }
 }
 push @$res, $desc_base . (($speed) ? ' at ' . $speed . ' bits/s' : ' failed');
 return ($ok == $n);
}

1;
