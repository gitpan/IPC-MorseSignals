package IPC::MorseSignals;

use strict;
use warnings;

use Time::HiRes qw/usleep/;
use POSIX qw/SIGUSR1 SIGUSR2/;

=head1 NAME

IPC::MorseSignals - Communicate between processes with Morse signals.

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

    use IPC::MorseSignals qw/msend mrecv/;

    my $pid = fork;
    if (!defined $pid) {
     die "fork() failed: $!";
    } elsif ($pid == 0) {
     local @SIG{qw/USR1 USR2/} = mrecv sub { print STDERR "recieved $_[0]!\n" };
     1 while 1;
    }
    msend "hello!\n" => $pid;
    waitpid $pid, 0;

=head1 DESCRIPTION

This module implements a rare form of IPC by sending Morse-like signals through C<SIGUSR1> and C<SIGUSR2>. It uses both signals C<SIGUSR1> and C<SIGUSR2>, so you won't be able to keep them for something else when you use this module.

But, seriously, use something else for your IPC. :)

=head1 FUNCTIONS

=head2 C<msend>

    msend $msg, $pid [, $speed ]

Sends the string C<$msg> to the process C<$pid> (or to all the processes C<@$pid> if $pid is an array ref) at C<$speed> bits per second. Default speed is 1000, don't set it too low or the target will miss bits and the whole message will be crippled.

=cut

sub msend {
 my ($msg, $pid, $speed) = @_;
 my @pid = (ref $pid eq 'ARRAY') ? @$pid : $pid;
 return unless @pid && $msg;
 $speed ||= 1000;
 my $delay = int(1_000_000 / $speed);
 my @bits = split //, unpack 'B*', $msg;
 my ($c, $n, @l) = (2, 0, 0, 0, 0);
 for (@bits) {
  if ($c == $_) {
   ++$n;
  } else {
   if ($n > $l[$c]) { $l[$c] = $n; }
   $n = 1;
   $c = $_;
  }
 }
 if ($n > $l[$c]) { $l[$c] = $n; }
 ($c, $n) = ($l[0] > $l[1]) ? (1, $l[1]) : (0, $l[0]); # Take the smallest
 ++$n;
 @bits = (($c) x $n, 1 - $c, @bits, 1 - $c, ($c) x $n);
 for (@bits) {
  my $sig = ($_ == 0) ? SIGUSR1 : SIGUSR2;
  usleep $delay;
  kill $sig, @pid;
 }
}

=head2 C<mrecv>

    mrecv $callback

Takes as its sole argument the callback triggered when a complete message is received, and returns two code references that should replace SIGUSR1 and SIGUSR2 signal handlers. Basically, you want to use it like this :

    local @SIG{qw/USR1 USR2/} = mrecv sub { ... };

=cut

sub mrecv {
 my ($cb) = @_;
 my ($bits, $state, $c, $n, $end) = ('', 0, undef, 0, undef);
 my $sighandler = sub {
  my ($b) = @_;
  if ($state == 2) {
   if ((substr $bits, -$n) eq $end) { # done
    substr $bits, -$n, $n, '';
    $cb->(pack 'B*', $bits);
   }
  } elsif ($state == 1) {
   if ($c != $b) {
    $state = 2;
    $end = (1 - $c) . $c x $n;
    $bits = '';
   }
   ++$n;
  } else {
   $c = $b;
   $n = 1;
   $state = 1;
  }
 };
 return sub {
  $bits .= 0;
  $sighandler->(0);
 }, sub {
  $bits .= 1;
  $sighandler->(1);
 };
}

=head1 EXPORT

This module exports on request its two only functions, L</msend> and L</mrecv>.

=cut

use base qw/Exporter/;

our @EXPORT         = ();
our %EXPORT_TAGS    = ( 'funcs' => [ qw/msend mrecv/ ] );
our @EXPORT_OK      = map { @$_ } values %EXPORT_TAGS;
$EXPORT_TAGS{'all'} = \@EXPORT_OK;

=head1 DEPENDENCIES

L<POSIX> (standard since perl 5) and L<Time::HiRes> (standard since perl 5.7.3) are required.

=head1 SEE ALSO

L<perlipc> for information about signals.

For truely useful IPC, search for shared memory, pipes and semaphores.

=head1 AUTHOR

Vincent Pit, C<< <perl at profvince.com> >>

You can contact me by mail or on #perl @ FreeNode (Prof_Vince).

=head1 BUGS

Please report any bugs or feature requests to
C<bug-ipc-morsesignals at rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=IPC-MorseSignals>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc IPC::MorseSignals

=head1 ACKNOWLEDGEMENTS

Thanks for the inspiration, mofino ! I hope this module will fill all your IPC needs. :)

=head1 COPYRIGHT & LICENSE

Copyright 2007 Vincent Pit, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1; # End of IPC::MorseSignals
