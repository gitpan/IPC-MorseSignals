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

my $BUILD_REQUIRES = {
 'utf8'                => 0,
 'Data::Dumper'        => 0,
 'Exporter'            => 0,
 'ExtUtils::MakeMaker' => 0,
 'POSIX'               => 0,
 'Test::More'          => 0,
};

sub build_req {
 my $tometa = ' >> $(DISTVNAME)/META.yml;';
 my $build_req = 'echo "build_requires:" ' . $tometa;
 foreach my $mod ( sort { lc $a cmp lc $b } keys %$BUILD_REQUIRES ) {
  my $ver = $BUILD_REQUIRES->{$mod};
  $build_req .= sprintf 'echo "    %-30s %s" %s', "$mod:", $ver, $tometa;
 }
 return $build_req;
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
    },
    dist                => {
        PREOP => 'pod2text lib/IPC/MorseSignals.pm > $(DISTVNAME)/README; '
                 . build_req,
        COMPRESS => 'gzip -9f', SUFFIX => 'gz',
    },
    clean               => { FILES => 'IPC-MorseSignals-*' },
);
