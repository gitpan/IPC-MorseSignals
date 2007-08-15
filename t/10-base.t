#!perl -T

use Test::More tests => 6;

use POSIX qw/SIGTERM SIGKILL EXIT_SUCCESS/;

use IPC::MorseSignals qw/msend mrecv/;

sub try2send {
 my ($msg, $desc) = @_;
 pipe $rdr, $wtr or die "pipe() failed : $!";
 my $pid = fork;
 if (!defined $pid) {
  die "fork() failed : $!";
 } elsif ($pid == 0) {
  close $rdr;
  local @SIG{qw/USR1 USR2/} = mrecv sub {
   print $wtr $_[0], "\n";
   exit EXIT_SUCCESS;
  };
  1 while 1;
 }
 close $wtr or die "close() failed : $!";
 msend $msg => $pid, 100;
 eval {
  local $SIG{ALRM} = sub { die };
  alarm 5;
  waitpid $pid, 0;
  alarm 0;
 };
 if ($@) {
  kill SIGINT,  $pid;
  kill SIGTERM, $pid;
  kill SIGKILL, $pid;
  die "$@ in $desc";
 }
 my $recv = do { local $/; <$rdr> };
 close $rdr;
 chomp $recv;
 ok($msg eq $recv, $desc);
}

try2send 'hello', 'ascii';
try2send 'éàùçà', 'extended';
try2send '€€€', 'unicode';
try2send 'a€bécàd€e', 'mixed';
try2send "\x{FF}", 'lots of bits';
try2send "a\0b", 'null character';
