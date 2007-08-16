#!perl -T

use Test::More tests => 7 * 5;

use POSIX qw/SIGINT SIGTERM SIGKILL EXIT_SUCCESS/;

use IPC::MorseSignals qw/msend mrecv/;

my $speed = 128;

sub trysend {
 my ($msg, $desc) = @_;
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
  die "$desc: died ($@)";
 }
 my $recv = do { local $/; <$rdr> };
 close $rdr;
 chomp $recv;
 ok($msg eq $recv, $desc);
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
