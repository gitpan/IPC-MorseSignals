#!perl -T

use strict;
use warnings;

use Test::More tests => 4;

use IPC::MorseSignals::Receiver;

my $pants = new IPC::MorseSignals::Receiver \%SIG;
ok(defined $pants, 'IMR object is defined');
ok(ref $pants eq 'IPC::MorseSignals::Receiver', 'IMR object is valid');
ok($pants->isa('Bit::MorseSignals::Receiver'), 'IMR is a BMR');

my $fake = { };
bless $fake, 'IPC::MorseSignal::Hlagh';
eval { Bit::MorseSignals::Receiver::reset($fake) };
ok($@ && $@ =~ /^First\s+argument/, "BMR methods only apply to BMR objects");
