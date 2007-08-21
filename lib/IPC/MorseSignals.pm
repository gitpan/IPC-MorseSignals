package IPC::MorseSignals;

use strict;
use warnings;

use utf8;

use Carp qw/croak/;
use POSIX qw/SIGUSR1 SIGUSR2/;
use Time::HiRes qw/usleep/;

use constant PID_BITS => 24;

=head1 NAME

IPC::MorseSignals - Communicate between processes with Morse signals.

=head1 VERSION

Version 0.06

=cut

our $VERSION = '0.06';

=head1 SYNOPSIS

    use IPC::MorseSignals qw/msend mrecv/;

    my $pid = fork;
    if (!defined $pid) {
     die "fork() failed: $!";
    } elsif ($pid == 0) {
     my $s = mrecv local %SIG, cb => sub {
      print STDERR "received $_[1] from $_[0]!\n";
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

    msend $msg, $pid [, speed => $speed, utf8 => $utf8, sign => $sign ]

Sends the string C<$msg> to the process C<$pid> (or to all the processes C<@$pid> if C<$pid> is an array ref) at C<$speed> bits per second. Default speed is 512, don't set it too low or the target will miss bits and the whole message will be crippled.
If the C<utf8> flag is set (default is unset), the string will first be encoded in UTF-8. The C<utf8> bit of the packet message is turned on, so that the receiver is aware of it. If the C<sign> flag is unset (default is set), the PID of the sender won't be shipped with the packet.

=cut

sub msend {
 my ($msg, $pid, @o) = @_;
 my @pids = (ref $pid eq 'ARRAY') ? @$pid : $pid;
 return unless defined $msg && length $msg;
 croak 'No PID was supplied' unless @pids;
 croak 'Optional arguments must be passed as key => value pairs' if @o % 2;
 my %opts = @o;
 $opts{speed} ||= 512;
 $opts{utf8}  ||= 0;
 $opts{sign}    = 1 unless defined $opts{sign};
 my $delay = int(1_000_000 / $opts{speed});

 my @head = (
  ($opts{utf8} ? 1 : 0),
  ($opts{sign} ? 1 : 0),
 );
 if ($opts{sign}) {
  my $n = 2 ** PID_BITS;
  push @head, ($$ & $n) ? 1 : 0 while ($n /= 2) >= 1;
 }

 my $tpl = 'B*';
 if ($opts{utf8}) {
  utf8::encode $msg;
  $tpl = 'U0' . $tpl;
 }
 my @bits = split //, unpack $tpl, $msg;

 unshift @bits, @head;
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
  kill $sig => @pids;
 }
}

=head2 C<mrecv>

    mrecv %SIG [, cb => $callback ]

Takes as its first argument the C<%SIG> hash and returns a hash reference that represent the current state of the receiver. C<%SIG>'s fields C<'USR1'> and C<'USR2'> will be replaced by the receiver's callbacks. C<cb> specifies the callback to trigger each time a complete message has arrived. Basically, you want to use it like this :

    my $rv = mrecv local %SIG, cb => sub { ... };

In the callback, C<$_[0]> is the sender's PID (or C<0> if the sender wanted to stay anonymous) and C<$_[1]> is the message received.

=cut

sub mreset;

sub mrecv (\%@) {
 my ($sig, @o) = @_;
 croak 'Optional arguments must be passed as key => value pairs' if @o % 2;
 my %opts = @o;
 my $s = { cb => $opts{cb} };
 mreset $s;

 my $sighandler = sub {
  my ($b) = @_;

  if ($s->{state} == 5) { # data

   $s->{bits} .= $b;
   if ((substr $s->{bits}, - $s->{n}) eq $s->{end}) {
    substr $s->{bits}, - $s->{n}, $s->{n}, '';
    my $tpl = 'B*';
    $tpl = 'U0' . $tpl if $s->{utf8};
    $s->{msg} = pack $tpl, $s->{bits};
    mreset $s;
    $s->{cb}->(@{$s}{qw/sender msg/}) if $s->{cb};
   }

  } elsif ($s->{state} == 4) { # sender signature

   if (length $s->{bits} < PID_BITS) {
    $s->{bits} .= $b;
   } else {
    my $n = 2 ** PID_BITS;
    my @b = split //, $s->{bits};
    $s->{sender} += $n * shift @b while ($n /= 2) >= 1;
    @{$s}{qw/state bits/} = (5, $b);
   }

  } elsif ($s->{state} == 3) { # signature flag

   @{$s}{qw/state sign/} = ($b ? 4 : 5, $b);

  } elsif ($s->{state} == 2) { # utf8 flag

   @{$s}{qw/state utf8/} = (3, $b);

  } elsif ($s->{state} == 1) { # end of signature

   if ($s->{c} != $b) {
    @{$s}{qw/state end/} = (2, (1 - $s->{c}) . $s->{c} x $s->{n});
   }
   ++$s->{n};

  } else { # first bit

   @{$s}{qw/state c n sender msg/} = (1, $b, 1, 0, '');

  }

 };

 @{$sig}{qw/USR1 USR2/} = (sub { $sighandler->(0) }, sub { $sighandler->(1) });

 return $s;
}

=head2 C<mreset>

    mreset $rcv

Resets the state of the receiver C<$rcv>. Useful to abort transfers.

=cut

sub mreset {
 my ($rcv) = @_;
 @{$rcv}{qw/state c n bits end utf8 sign/} = (0, undef, 0, '', '', 0, 0);
}

=head2 C<mbusy>

    mbusy $rcv

Returns true if the receiver C<$rcv> is currently busy with incoming data, or false otherwise.

=cut

sub mbusy {
 my ($rcv) = @_;
 return $rcv->{state} > 0;
}

=head2 C<mlastsender>

    mlastmsg $rcv

Holds the PID of the last process that sent data to the receiver C<$rcv>, C<0> if that process was anonymous, or C<undef> if no message has arrived yet. It isn't cleared by L</mreset>.

=cut

sub mlastsender {
 my ($rcv) = @_;
 return $rcv->{sender};
}

=head2 C<mlastmsg>

    mlastmsg $rcv

Holds the last message received by C<$rcv>, or C<undef> if no message has arrived yet. It isn't cleared by L</mreset>.

=cut

sub mlastmsg {
 my ($rcv) = @_;
 return $rcv->{msg};
}

=head1 EXPORT

This module exports any of its functions only on request.

=cut

use base qw/Exporter/;

our @EXPORT         = ();
our %EXPORT_TAGS    = ( 'funcs' => [ qw/msend mrecv mreset mbusy mlastsender mlastmsg/ ] );
our @EXPORT_OK      = map { @$_ } values %EXPORT_TAGS;
$EXPORT_TAGS{'all'} = \@EXPORT_OK;

=head1 PROTOCOL

Each byte of the data string is converted into its bits sequence, with bits of highest weight coming first. All those bits sequences are put into the same order as the characters occur in the string.

The header is composed by the C<utf8> bit (if the data has to be decoded to UTF-8), the C<sign> bit (if sender gives its PID in the header), and then 24 bits representing the sender's PID (with highest weight coming first) if the C<sign> bit is set.

The emitter computes then the longuest sequence of successives 0 (say, m) and 1 (n) in the concatenation of the header and the data. A signature is then chosen :

=over 4

=item - If m > n, we take n+1 times 1 follewed by one 0 ;

=item - Otherwise, we take m+1 times 0 follewed by one 1.

=back

The signal is then formed by concatenating the signature, the header, the data bits and the reversed signature (i.e. the bits of the signature in the reverse order).

    a ... a b | u s [ p23 ... p0 ] | ... data ... | b a ... a
    signature |      header        |     data     | reversed signature

The receiver knows that the signature has been sent when it has catched at least one 0 and one 1. The signal is completely transferred when it has received for the first time the whole reversed signature.

=head1 CAVEATS

This type of IPC is highly unreliable. Send little data at slow speed if you want it to reach its goal.

C<SIGUSR{1,2}> seem to interrupt sleep, so it's not a good idea to transfer data to a sleeping process.

=head1 DEPENDENCIES

L<Carp> (standard since perl 5), L<POSIX> (idem), L<Time::HiRes> (since perl 5.7.3) and L<utf8> (since perl 5.6) are required.

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
