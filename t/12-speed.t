#!perl -T

use Test::More tests => 12;

use POSIX qw/SIGINT SIGTERM SIGKILL EXIT_SUCCESS EXIT_FAILURE WIFEXITED WEXITSTATUS/;

use IPC::MorseSignals qw/msend mrecv/;

my @res;

sub tryspeed {
 my ($l, $n) = @_;
 my $speed = 2 ** 16;
 my $ok = 0;
 my @alpha = ('a' .. 'z');
 my $msg = join '', map { $alpha[rand @alpha] } 1 .. $l;
 my $desc;
 while (($speed > 1) && ($ok < $n)) {
  $speed /= 2;
  $desc = "$n sends of $l bytes at $speed bits/s";
  $ok = 0;
  diag("try $desc...");
TRY:
  for (1 .. $n) {
   my $pid = fork;
   if (!defined $pid) {
    die "$desc: fork() failed : $!";
   } elsif ($pid == 0) {
    local @SIG{qw/USR1 USR2/} = mrecv sub {
     exit(($msg eq $_[0]) ? EXIT_SUCCESS : EXIT_FAILURE);
    };
    1 while 1;
    exit EXIT_FAILURE;
   }
   eval {
    local $SIG{ALRM} = sub { die 'timeout' };
    my $a = (int(100 * (3 * $l) / $speed) || 1);
    $a = 10 if $a > 10;
    alarm $a;
    msend $msg => $pid, speed => $speed;
    waitpid $pid, 0;
    $ok += (WIFEXITED($?) && (WEXITSTATUS($?) == EXIT_SUCCESS));
   };
   alarm 0;
   if ($@) {
    kill SIGINT,  $pid;
    kill SIGTERM, $pid;
    kill SIGKILL, $pid;
    last TRY;
   }
  }
 }
 $desc = "$l bytes sent $n times";
 ok($speed >= 1, $desc);
 push @res, $desc . (($speed) ? ' at ' . $speed . ' bits/s' : ' failed');
}

tryspeed 4, 1;
tryspeed 4, 5;
tryspeed 4, 10;
tryspeed 4, 50;
tryspeed 16, 1;
tryspeed 16, 5;
tryspeed 16, 10;
tryspeed 64, 1;
tryspeed 64, 5;
tryspeed 64, 10;
tryspeed 256, 1;
tryspeed 1024, 1;

diag '=== Summary ===';
diag $_ for @res;
