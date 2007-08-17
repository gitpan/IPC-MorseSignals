package IPC::MorseSignals;

use strict;
use warnings;

use utf8;

use Time::HiRes qw/usleep/;
use POSIX qw/SIGUSR1 SIGUSR2/;

=head1 NAME

IPC::MorseSignals - Communicate between processes with Morse signals.

=head1 VERSION

Version 0.04

=cut

our $VERSION = '0.04';

=head1 SYNOPSIS

    use IPC::MorseSignals qw/msend mrecv/;

    my $pid = fork;
    if (!defined $pid) {
     die "fork() failed: $!";
    } elsif ($pid == 0) {
     local @SIG{qw/USR1 USR2/} = mrecv sub {
      print STDERR "received $_[0]!\n";
      exit
     };
     1 while 1;
    }
    msend "hello!\n" => $pid;
    waitpid $pid, 0;

=head1 DESCRIPTION

This module implements a rare form of IPC by sending Morse-like signals through C<SIGUSR1> and C<SIGUSR2>. Both of those signals are used, so you won't be able to keep them for something else when you use this module.

But, seriously, use something else for your IPC. :)

=head1 FUNCTIONS

=head2 C<msend>

    msend $msg, $pid [, speed => $speed, utf8 => $utf8 ]

Sends the string C<$msg> to the process C<$pid> (or to all the processes C<@$pid> if $pid is an array ref) at C<$speed> bits per second. If the C<utf8> flag is set, the string will first be encoded in UTF-8. In this case, you must turn it on for L</mrecv> as well.
Default speed is 512, don't set it too low or the target will miss bits and the whole message will be crippled. The C<utf8> flag is turned off by default;

=cut

sub msend {
 my ($msg, $pid, @o) = @_;
 my @pid = (ref $pid eq 'ARRAY') ? @$pid : $pid;
 return unless @pid && $msg && !(@o % 2);
 my %opts = @o;
 $opts{speed} ||= 512;
 $opts{utf8}  ||= 0;
 my $delay = int(1_000_000 / $opts{speed});
 my $tpl = 'B*';
 if ($opts{utf8}) {
  utf8::encode $msg;
  $tpl = 'U0' . $tpl;
 }
 my @bits = split //, unpack $tpl, $msg;
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

    mrecv $callback [, utf => $utf8 ]

Takes as its first argument the callback triggered when a complete message is received, and returns two code references that should replace SIGUSR1 and SIGUSR2 signal handlers. Basically, you want to use it like this :

    local @SIG{qw/USR1 USR2/} = mrecv sub { ... };

Turn on the utf8 flag if you know that the incoming strings are expected to be in UTF-8. This flag is turned off by default.

=cut

sub mrecv {
 my ($cb, @o) = @_;
 return unless $cb && !(@o % 2);
 my %opts = @o;
 $opts{utf8} ||= 0;
 my ($bits, $state, $c, $n, $end) = ('', 0, undef, 0, '');
 my $sighandler = sub {
  my ($b) = @_;
  if ($state == 2) {
   if (defined $bits && (substr $bits, -$n) eq $end) { # done
    substr $bits, -$n, $n, '';
    my $tpl = 'B*';
    $tpl = 'U0' . $tpl if $opts{utf8};
    my $msg = pack $tpl, $bits;
    $cb->($msg);
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

=head1 PROTOCOL

Each byte of the data string is converted into its bits sequence, with bits of highest weight coming first. All those bits sequences are put into the same order as the characters occur in the string. The emitter computes then the longuest sequence of successives 0 (say, C<m>) and 1 (C<n>). A signature is then chosen :

=over 4

=item If C(m > n), we take C<n+1> times 1 follewed by C<1> 0 ;

=item Otherwise, we take C<m+1> times 0 follewed by C<1> 1.

=back

The signal is then formed by concatenating the signature, the data bits and the reversed signature (i.e. the bits of the signature in the reverse order).

The receiver knows that the signature has been sent when it has catched at least one 0 and one 1. The signal is completely transferred when it has received for the first time the whole reversed signature.

=head1 CAVEATS

This type of IPC is highly unreliable. Send little data at slow speed if you want it to reach its goal.

SIGUSR{1,2} seem to interrupt sleep, so it's not a good idea to transfer data to a sleeping process.

=head1 DEPENDENCIES

L<POSIX> (standard since perl 5) and L<Time::HiRes> (standard since perl 5.7.3) are required.

=head1 SEE ALSO

L<perlipc> for information about signals in perl.

For truly useful IPC, search for shared memory, pipes and semaphores.

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
