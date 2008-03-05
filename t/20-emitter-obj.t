#!perl -T

use strict;
use warnings;

use Test::More tests => 19;

use IPC::MorseSignals::Emitter;

my $deuce = new IPC::MorseSignals::Emitter;
ok(defined $deuce, 'BME object is defined');
ok(ref $deuce eq 'IPC::MorseSignals::Emitter', 'IME object is valid');
ok($deuce->isa('Bit::MorseSignals::Emitter'), 'IME is a BME');

my $fake = { };
bless $fake, 'IPC::MorseSignal::Hlagh';
eval { IPC::MorseSignals::Emitter::speed($fake) };
ok($@ && $@ =~ /^First\s+argument/, "IME methods only apply to IME objects");
eval { Bit::MorseSignals::Emitter::reset($fake) };
ok($@ && $@ =~ /^First\s+argument/, "BME methods only apply to BME objects");

ok($deuce->delay == 1, 'default delay is 1');
ok($deuce->speed == 1, 'default speed is 1');

$deuce->delay(0.1);
ok(abs($deuce->delay - 0.1) < 0.01, 'set delay is 0.1');
ok($deuce->speed == 10, 'resulting speed is 10');

$deuce->speed(100);
ok($deuce->speed == 100, 'set speed is 100');
ok(abs($deuce->delay - 0.01) < 0.001, 'resulting speed is 0.01');

$deuce = new IPC::MorseSignals::Emitter delay => 0.25;
ok(abs($deuce->delay - 0.25) < 0.025, 'initial delay is 0.25');
ok($deuce->speed == 4, 'resulting initial speed is 4');

$deuce = new IPC::MorseSignals::Emitter speed => 40;
ok($deuce->speed == 40, 'initial speed is 40');
ok(abs($deuce->delay - 0.025) < 0.0025, 'resulting initial delay is 0.025');

$deuce = new IPC::MorseSignals::Emitter delay => 0.25, speed => 40;
ok(abs($deuce->delay - 0.25) < 0.025, 'delay supersedes speed');

$deuce = new IPC::MorseSignals::Emitter delay => 0;
ok($deuce->delay == 1, 'wrong delay results in 1');

$deuce = new IPC::MorseSignals::Emitter speed => 0.1;
ok($deuce->delay == 1, 'wrong speed results in 1');

$deuce = new IPC::MorseSignals::Emitter delay => 0, speed => -0.1;
ok($deuce->delay == 1, 'wrong delay and speed result in 1');
