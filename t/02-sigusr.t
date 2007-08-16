#!perl -T

use Test::More tests => 2;

use POSIX qw/SIGTERM SIGKILL EXIT_FAILURE EXIT_SUCCESS/;

sub trysig {
 my ($n, $s) = @_;
 my $pid = fork;
 if (!defined $pid) {
  die "$s: fork() failed : $!";
 } elsif ($pid == 0) {
  local $SIG{$s} = sub { exit EXIT_SUCCESS };
  1 while 1;
 }
 my $ret = EXIT_FAILURE;
 eval {
  local $SIG{ALRM} = sub { die };
  alarm 1;
  kill $n, $pid;
  waitpid $pid, 0;
  $ret = $?;
  alarm 0;
 };
 if ($@) {
  kill SIGINT,  $pid;
  kill SIGTERM, $pid;
  kill SIGKILL, $pid;
  die "$s: $@";
 }
 ok($ret == EXIT_SUCCESS, $s);
}

trysig SIGUSR1, 'USR1';
trysig SIGUSR2, 'USR2';
