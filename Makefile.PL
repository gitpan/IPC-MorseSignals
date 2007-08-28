use strict;
use warnings;
use ExtUtils::MakeMaker;

BEGIN {
 eval { require Config };
 die "You need the Config module to install this distribution, that's what happened" if $@;
 Config->import qw/%Config/;
}

my %sigs;
@sigs{split ' ', $Config{sig_name}} = ();

for (qw/USR1 USR2/) {
 print "Checking if you have SIG$_... ";
 unless (exists $sigs{$_}) {
  print "no\n";
  die "Installation stops right here,";
 }
 print "yes\n";
}

WriteMakefile(
    NAME                => 'IPC::MorseSignals',
    AUTHOR              => 'Vincent Pit <perl@profvince.com>',
    LICENSE             => 'perl',
    VERSION_FROM        => 'lib/IPC/MorseSignals.pm',
    ABSTRACT_FROM       => 'lib/IPC/MorseSignals.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'Carp'        => 0,
        'Exporter'    => 0,
        'POSIX'       => 0,
        'Test::More'  => 0,
        'Time::HiRes' => 0,
        'utf8'        => 0,
    },
    dist                => {
        PREOP => 'pod2text lib/IPC/MorseSignals.pm > $(DISTVNAME)/README',
        COMPRESS => 'gzip -9f', SUFFIX => 'gz',
    },
    clean               => { FILES => 'IPC-MorseSignals-*' },
);
