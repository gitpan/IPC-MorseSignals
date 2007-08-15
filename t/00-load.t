#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'IPC::MorseSignals' );
}

diag( "Testing IPC::MorseSignals $IPC::MorseSignals::VERSION, Perl $], $^X" );
