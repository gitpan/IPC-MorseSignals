#!perl -T

use Test::More tests => 12;

use POSIX qw/SIGINT SIGTERM SIGKILL EXIT_SUCCESS/;

use IPC::MorseSignals qw/msend mrecv/;

my @res;

sub tryspeed {
 my ($l, $n) = @_;
 my $speed = 2 ** 16;
 my $ok = 0;
 my $msg = join '', map { chr int rand 256 } 1 .. $l;
 my $desc;
 while (($speed > 1) && ($ok < $n)) {
  $desc = "$n sends of $l bytes at $speed bits/s";
  $speed /= 2;
  $ok = 0;
  diag("try $desc...");
TRY:
  for (1 .. $n) {
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
    my $a = (int(100 * (3 * $l) / $speed) || 1);
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
    last TRY;
   }
   my $recv = do { local $/; <$rdr> };
   close $rdr or die "$desc: close() failed : $!";
   last TRY unless $recv;
   chomp $recv;
   last TRY unless $msg eq $recv;
   ++$ok;
  }
 }
 $desc = "$l bytes sent $n times";
 ok($speed, $desc);
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
