package IPC::MorseSignals;

use strict;
use warnings;

=head1 NAME

IPC::MorseSignals - Communicate between processes with Morse signals.

=head1 VERSION

Version 0.12

=cut

our $VERSION = '0.12';

=head1 SYNOPSIS

    # In the sender process
    use IPC::MorseSignals::Emitter;

    my $deuce = new IPC::MorseSignals::Emitter speed => 1024;
    $deuce->post('HLAGH') for 1 .. 3;
    $deuce->send($pid);

    ...

    # In the receiver process
    use IPC::MorseSignals::Receiver;

    local %SIG;
    my $pants = new IPC::MorseSignals::Receiver \%SIG, done => sub {
     print STDERR "GOT $_[1]\n";
    };

=head1 DESCRIPTION

This module implements a rare form of IPC by sending Morse-like signals through C<SIGUSR1> and C<SIGUSR2>. Both of those signals are used, so you won't be able to keep them for something else when you use this module.

=over 4

=item L<IPC::MorseSignals::Emitter> is a base class for emitters ;

=item L<IPC::MorseSignals::Receiver> is a base class for receivers.

=back

But, seriously, use something else for your IPC. :)

=head1 DEPENDENCIES

You need the complete L<Bit::MorseSignals> distribution.

L<Carp> (standard since perl 5), L<POSIX> (idem) and L<Time::HiRes> (since perl 5.7.3) are also required.

=head1 SEE ALSO

L<IPC::MorseSignals::Emitter>, L<IPC::MorseSignals::Receiver>.

L<Bit::MorseSignals>, L<Bit::MorseSignals::Emitter>, L<Bit::MorseSignals::Receiver>.

L<perlipc> for information about signals in perl.

For truly useful IPC, search for shared memory, pipes and semaphores.

=head1 AUTHOR

Vincent Pit, C<< <perl at profvince.com> >>, L<http://www.profvince.com>.

You can contact me by mail or on #perl @ FreeNode (vincent or Prof_Vince).

=head1 BUGS

Please report any bugs or feature requests to C<bug-ipc-morsesignals at rt.cpan.org>, or through the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=IPC-MorseSignals>.  I will be notified, and then you'll automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc IPC::MorseSignals

=head1 ACKNOWLEDGEMENTS

Thanks for the inspiration, mofino ! I hope this module will fill all your IPC needs. :)

=head1 COPYRIGHT & LICENSE

Copyright 2007-2008 Vincent Pit, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of IPC::MorseSignals
