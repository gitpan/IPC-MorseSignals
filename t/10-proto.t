#!perl -T

use Test::More tests => 2;

use POSIX qw/SIGINT SIGTERM SIGKILL SIGHUP EXIT_FAILURE/;

use IPC::MorseSignals qw/msend mrecv mreset/;

my $lives = 5;

sub spawn {
 --$lives;
 die 'forked too many times' if $lives < 0;
 pipe my $rdr, my $wtr or die "pipe() failed: $!";
 my $pid = fork;
 if (!defined $pid) {
  die "fork() failed: $!";
 } elsif ($pid == 0) {
  close $rdr or die "close() failed: $!";
  my $block = 0;
  my $s = mrecv local %SIG, cb => sub {
   if ($block) {
    $block = 0;
   } else {
    select $wtr; $| = 1;
    print $wtr $_[0], ':', $_[1], "\n";
    select $wtr; $| = 1;
   }
  };
  $SIG{HUP} = sub { mreset $s };
  $SIG{__WARN__} = sub { $block = 1 };
  1 while 1;
  exit EXIT_FAILURE;
 }
 close $wtr or die "close() failed: $!";
 return ($pid, $rdr);
}

sub slaughter {
 my ($pid) = @_;
 kill SIGINT  => $pid;
 kill SIGTERM => $pid;
 kill SIGKILL => $pid;
 waitpid $pid, 0;
}

my ($pid, $rdr) = spawn;

sub trysend {
 my ($sign, $desc) = @_;
 my $speed = 2 ** 16;
 my $ok = 0;
 while (!$ok && (($speed /= 2) >= 1)) {
  my $r = '';
  eval {
   local $SIG{ALRM} = sub { die 'timeout' };
   local $SIG{__WARN__} = sub { die 'do not want warnings' };
   my $a = (int(300 / $speed) || 1);
   $a = 10 if $a > 10;
   alarm $a;
   kill SIGHUP => $pid;
   msend 'x' => $pid, speed => $speed, sign => $sign;
   $r = <$rdr>;
  };
  kill SIGHUP => $pid if $@;
  alarm 0;
  if (!defined $r) { # Something bad happened, respawn
   close $rdr or die "close() failed: $!";
   slaughter $pid;
   ($pid, $rdr) = spawn;
   $speed *= 2;      # Retry this speed
  } else {
   chomp $r;
   my ($p, $m) = split /:/, $r;
   $ok = ($m eq 'x') && ($p == ($sign ? $$ : 0)) if defined $m and defined $p;
  }
 }
 ok($ok, $desc);
}

trysend 0, 'anonymous';
trysend 1, 'signed';

slaughter $pid;
