#!perl -T

use Test::More tests => 2;

require IPC::MorseSignals;

for (qw/msend mrecv/) {
 eval { Variable::Magic->import($_) };
 ok(!$@, 'import ' . $_);
}
