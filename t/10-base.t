#!perl -T

use Test::More tests => 7 * 5;

use POSIX qw/SIGINT SIGTERM SIGKILL EXIT_SUCCESS/;

use IPC::MorseSignals qw/msend mrecv/;

sub trysend {
 my ($msg, $desc) = @_;
 my $speed = 2 ** 16;
 my $ok = 0;
SPEED:
 while (($speed > 1) && !$ok) {
  $speed /= 2;
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
   local $SIG{ALRM} = sub { die 'timeout' };
   my $a = (int(100 * (3 * length $msg) / $speed) || 1);
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
   next SPEED;
  }
  my $recv = do { local $/; <$rdr> };
  close $rdr or die "$desc: close() failed : $!";
  next SPEED unless $recv;
  chomp $recv;
  next SPEED unless $msg eq $recv;
  $ok = 1;
 }
 ok($speed >= 1, $desc);
}

for (1 .. 5) {
 trysend 'hello', 'ascii';
 trysend 'éàùçà', 'extended';
 trysend '€€€', 'unicode';
 trysend 'a€bécàd€e', 'mixed';
 trysend "\0" x 10, 'few bits';
 trysend "\x{FF}" x 10, 'lots of bits';
 trysend "a\0b", 'null character';
}
