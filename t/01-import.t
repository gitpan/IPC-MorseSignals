#!perl -T

use Test::More tests => 6;

require IPC::MorseSignals;

for (qw/msend mrecv mreset mbusy mlastsender mlastmsg/) {
 eval { Variable::Magic->import($_) };
 ok(!$@, 'import ' . $_);
}
