#!perl -T

use Test::More tests => 2;

use POSIX qw/SIGINT SIGTERM SIGKILL EXIT_SUCCESS EXIT_FAILURE WIFEXITED WEXITSTATUS/;

my ($a, $b) = (0, 0);

local $SIG{'USR1'} = sub { ++$a };
local $SIG{'USR2'} = sub { ++$b };

kill SIGUSR1 => $$;
ok(($a == 1) && ($b == 0), 'SIGUSR1');

kill SIGUSR2 => $$;
ok(($a == 1) && ($b == 1), 'SIGUSR2');
