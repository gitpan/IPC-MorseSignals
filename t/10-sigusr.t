#!perl -T

use strict;
use warnings;

use Test::More tests => 2;

use POSIX qw/SIGUSR1 SIGUSR2/;

my ($a, $b) = (0, 0);

local $SIG{'USR1'} = sub { ++$a };
local $SIG{'USR2'} = sub { ++$b };

kill SIGUSR1 => $$;
ok(($a == 1) && ($b == 0), 'SIGUSR1');

kill SIGUSR2 => $$;
ok(($a == 1) && ($b == 1), 'SIGUSR2');
