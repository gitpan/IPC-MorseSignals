package IPC::MorseSignals::TestSuite;

use strict;
use warnings;

use Data::Dumper;
use POSIX qw/pause SIGINT SIGTERM SIGKILL SIGHUP EXIT_FAILURE/;

use IPC::MorseSignals::Emitter;
use IPC::MorseSignals::Receiver;

use base qw/Exporter/;

our @EXPORT_OK = qw/try bench init cleanup/;

$Data::Dumper::Indent = 0;

my ($lives, $pid, $rdr);

sub spawn {
 --$lives;
 die 'forked too many times' if $lives < 0;
 pipe $rdr, my $wtr or die "pipe() failed: $!";
 $pid = fork;
 if (!defined $pid) {
  die "fork() failed: $!";
 } elsif ($pid == 0) {
  local %SIG;
  close $rdr or die "close() failed: $!";
  select $wtr;
  $| = 1;
  $SIG{__WARN__} = sub { print $wtr "!warn\n"; };
  my $rcv = new IPC::MorseSignals::Receiver \%SIG, done => sub {
   print $wtr Dumper($_[1]), "\n";
  };
  my $ppid = getppid;
  $SIG{ALRM} = sub { alarm 1; kill SIGHUP => $ppid };
  alarm 1;
  $SIG{HUP}  = sub { alarm 0; $rcv->reset }; # We can reset the alarm here.
  pause while 1;
  exit EXIT_FAILURE;
 }
 my $ready = 0;
 local $SIG{HUP} = sub { $ready = 1 };
 sleep 1 until $ready;
 close $wtr or die "close() failed: $!";
 my $oldfh = select $rdr;
 $| = 1;
 select $oldfh;
}

sub slaughter {
 if (defined $rdr) {
  close $rdr or die "close() falied: $!";
  undef $rdr;
 }
 if (defined $pid) {
  kill SIGINT  => $pid;
  kill SIGTERM => $pid;
  kill SIGKILL => $pid;
  waitpid $pid, 0;
  undef $pid;
 }
}

sub init {
 ($lives) = @_;
 $lives ||= 10;
 undef $pid;
 undef $rdr;
 spawn;
}

sub cleanup { slaughter }

my $snd = new IPC::MorseSignals::Emitter;

sub try {
 my ($msg) = @_;
 my $speed = 2 ** 16;
 my $ok = 0;
 my @ret;
 while (!$ok && (($speed /= 2) >= 1)) {
  my $r = '';
  my $dump = Dumper($msg);
  1 while chomp $dump;
  eval {
   local $SIG{ALRM} = sub { die 'timeout' };
   local $SIG{__WARN__} = sub { alarm 0; die 'do not want warnings' };
   my $a = (int(100 * (3 * length $msg) / $speed) || 1);
   $a = 10 if $a > 10;
   alarm $a;
   kill SIGHUP => $pid;
   $snd->post($msg);
   $snd->speed($speed);
   $snd->send($pid);
   $r = <$rdr>;
   alarm 0;
  };
  if (!defined $r) { # Something bad happened, respawn
   slaughter;
   spawn;
  } else {
   1 while chomp $r;
   if ($r eq $dump) {
    $ok = 1;
   } else {
    kill SIGHUP => $pid;
   }
  }
 }
 return ($ok) ? $speed : 0;
}

sub bench {
 my ($l, $n, $diag, $res) = @_;
 my $speed = 2 ** 16;
 my $ok = 0;
 my @alpha = ('a' .. 'z');
 my $msg = join '', map { $alpha[rand @alpha] } 1 .. $l;
 my $dump = Dumper($msg);
 my $desc_base = "$l bytes sent $n time" . ('s' x ($n != 1));
 while (($ok < $n) && (($speed /= 2) >= 1)) {
  $ok = 0;
  my $desc = "$desc_base at $speed bits/s";
  $diag->("try $desc...");
TRY:
  for (1 .. $n) {
   my $r = '';
   eval {
    local $SIG{ALRM} = sub { die 'timeout' };
    local $SIG{__WARN__} = sub { alarm 0; die 'do not want warnings' };
    my $a = (int(100 * (3 * $l) / $speed) || 1);
    $a = 10 if $a > 10;
    alarm $a;
    kill SIGHUP => $pid;
    $snd->post($msg);
    $snd->speed($speed);
    $snd->send($pid);
    $r = <$rdr>;
    alarm 0;
   };
   if (!defined $r) { # Something bad happened, respawn
    slaughter;
    spawn;
    last TRY;
   } else {
    1 while chomp $r;
    if ($r eq $dump) {
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
