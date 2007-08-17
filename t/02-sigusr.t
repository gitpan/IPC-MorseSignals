#!perl -T

use Test::More tests => 2;

use POSIX qw/SIGINT SIGTERM SIGKILL EXIT_SUCCESS EXIT_FAILURE WIFEXITED WEXITSTATUS/;

sub trysig {
 my ($n, $s) = @_;
 my $pid = fork;
 if (!defined $pid) {
  die "$s: fork() failed : $!";
 } elsif ($pid == 0) {
  local $SIG{$s} = sub { exit EXIT_SUCCESS };
  1 while 1;
  exit EXIT_FAILURE;
 }
 sleep 1;
 my $ret = 0;
 eval {
  local $SIG{ALRM} = sub { die };
  alarm 1;
  kill $n, $pid;
  waitpid $pid, 0;
  $ret = (WIFEXITED($?) && (WEXITSTATUS($?) == EXIT_SUCCESS));
  alarm 0;
 };
 if ($@) {
  kill SIGINT,  $pid;
  kill SIGTERM, $pid;
  kill SIGKILL, $pid;
  die "$s: $@";
 }
 ok($ret, $s);
}

trysig SIGUSR1, 'USR1';
trysig SIGUSR2, 'USR2';
