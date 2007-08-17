#!perl -T

use Test::More tests => 7 * 5;

use POSIX qw/SIGINT SIGTERM SIGKILL EXIT_SUCCESS EXIT_FAILURE WIFEXITED WEXITSTATUS/;

use IPC::MorseSignals qw/msend mrecv/;

use utf8;

sub trysend8 {
 my ($msg, $desc) = @_;
 my $speed = 2 ** 16;
 my $ok = 0;
 $desc .= ' (unicode)';
SPEED:
 while (($speed > 1) && !$ok) {
  $speed /= 2;
  my $pid = fork;
  if (!defined $pid) {
   die "$desc: fork() failed : $!";
  } elsif ($pid == 0) {
   local @SIG{qw/USR1 USR2/} = mrecv sub {
    exit(($msg eq $_[0]) ? EXIT_SUCCESS : EXIT_FAILURE);
   }, utf8 => 1;
   1 while 1;
   exit EXIT_FAILURE;
  }
  my $ret = EXIT_FAILURE;
  eval {
   local $SIG{ALRM} = sub { die 'timeout' };
   my $a = (int(100 * (3 * length $msg) / $speed) || 1);
   $a = 10 if $a > 10;
   alarm $a;
   msend $msg => $pid, speed => $speed, utf8 => 1;
   waitpid $pid, 0;
   $ok = (WIFEXITED($?) && (WEXITSTATUS($?) == EXIT_SUCCESS));
  };
  alarm 0;
  if ($@) {
   kill SIGINT,  $pid;
   kill SIGTERM, $pid;
   kill SIGKILL, $pid;
  }
 }
 ok($speed >= 1, $desc);
}

for (1 .. 5) {
 trysend8 'hello', 'ascii';
 trysend8 "\0" x 10, 'few bits';
 trysend8 "\x{FF}" x 10, 'lots of bits';
 trysend8 "a\0b", 'null character';
 trysend8 'éàùçà', 'extended';
 trysend8 '€€€', 'unicode';
 trysend8 'a€bécàd€e', 'mixed';
}
