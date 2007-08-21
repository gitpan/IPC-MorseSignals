#!perl -T

use Test::More tests => 10;

use POSIX qw/SIGINT SIGTERM SIGKILL SIGHUP EXIT_SUCCESS EXIT_FAILURE/;

use IPC::MorseSignals qw/msend mrecv mreset/;

my $lives = 10;

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
    print $wtr $_[1], "\n";
    select $wtr; $| = 1;
   }
  };
  $SIG{HUP} = sub { mreset $s };
  $SIG{__WARN__} = sub { $block = 1; };
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

my @res;

my ($pid, $rdr) = spawn;

sub tryspeed {
 my ($l, $n) = @_;
 my $speed = 2 ** 16;
 my $ok = 0;
 my @alpha = ('a' .. 'z');
 my $msg = join '', map { $alpha[rand @alpha] } 1 .. $l;
 my $desc_base = "$l bytes sent $n times";
 while (($ok < $n) && (($speed /= 2) >= 1)) {
  my $desc = "$desc_base at $speed bits/s";
  diag("try $desc...");
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
    msend $msg => $pid, speed => $speed;
    $r = <$rdr>;
   };
   kill SIGHUP => $pid if $@;
   alarm 0;
   if (!defined $r) { # Something bad happened, respawn
    close $rdr or die "close() failed: $!";
    slaughter $pid;
    ($pid, $rdr) = spawn;
    redo TRY;         # Retry this send
   } else {
    chomp $r;
    if ($r eq $msg) {
     ++$ok;
    } else {
     kill SIGHUP => $pid;
     last TRY;
    }
   }
  }
 }
 ok($ok >= $n, $desc_base);
 push @res, $desc_base . (($speed) ? ' at ' . $speed . ' bits/s' : ' failed');
}

tryspeed 4,   1;
tryspeed 4,   4;
tryspeed 4,   16;
tryspeed 4,   64;
tryspeed 16,  1;
tryspeed 16,  4;
tryspeed 16,  16;
tryspeed 64,  1;
tryspeed 64,  4;
tryspeed 256, 1;

slaughter $pid;

diag '=== Summary ===';
diag $_ for sort {
 my ($l1, $n1) = $a =~ /(\d+)\D+(\d+)/;
 my ($l2, $n2) = $b =~ /(\d+)\D+(\d+)/;
 $l1 <=> $l2 || $n1 <=> $n2
} @res;
