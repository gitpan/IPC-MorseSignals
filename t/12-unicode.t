#!perl -T

use Test::More tests => 7 * 3;

use POSIX qw/SIGINT SIGTERM SIGKILL SIGHUP EXIT_FAILURE/;

use IPC::MorseSignals qw/msend mrecv mreset/;

use utf8;

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
  binmode $wtr, ':utf8';
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
  $SIG{__WARN__} = sub { $block = 1 };
  1 while 1;
  exit EXIT_FAILURE;
 }
 close $wtr or die "close() failed: $!";
 binmode $rdr, ':utf8';
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

sub trysend8 {
 my ($msg, $desc) = @_;
 my $speed = 2 ** 16;
 my $ok = 0;
 $desc .= ' (unicode)';
 while (!$ok && (($speed /= 2) >= 1)) {
  my $r = '';
  eval {
   local $SIG{ALRM} = sub { die 'timeout' };
   local $SIG{__WARN__} = sub { die 'do not want warnings' };
   my $a = (int(100 * (3 * length $msg) / $speed) || 1);
   $a = 10 if $a > 10;
   alarm $a;
   kill SIGHUP => $pid;
   msend $msg => $pid, speed => $speed, utf8 => 1, sign => 0;
   $r = <$rdr>;
  };
  kill SIGHUP => $pid if $@;
  alarm 0;
  if (!defined $r) { # Something bad happened, respawn
   close $rdr or die "close() failed: $!";
   slaughter $pid;
   ($pid, $rdr) = spawn;
   $speed *= 2;       # Retry this speed
  } else {
   chomp $r;
   if ($r eq $msg) {
    $ok = 1;
   } else {
    kill SIGHUP => $pid;
   }
  }
 }
 ok($ok, $desc);
}

for (1 .. 3) {
 trysend8 'hello', 'ascii';
 trysend8 "\0" x 10, 'few bits';
 trysend8 "\x{FF}" x 10, 'lots of bits';
 trysend8 "a\0b", 'null character';
 trysend8 'éàùçà', 'extended';
 trysend8 '€€€', 'unicode';
 trysend8 'a€bécàd€e', 'mixed';
}

slaughter $pid;
