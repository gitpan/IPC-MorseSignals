use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'IPC::MorseSignals',
    AUTHOR              => 'Vincent Pit <perl@profvince.com>',
    LICENSE             => 'perl',
    VERSION_FROM        => 'lib/IPC/MorseSignals.pm',
    ABSTRACT_FROM       => 'lib/IPC/MorseSignals.pm',
    PL_FILES            => {},
    PREREQ_PM => {
        'POSIX'       => 0,
        'Test::More'  => 0,
        'Time::HiRes' => 0,
    },
    dist                => {
        PREOP => 'pod2text lib/IPC/MorseSignals.pm > $(DISTVNAME)/README',
        COMPRESS => 'gzip -9f', SUFFIX => 'gz',
    },
    clean               => { FILES => 'IPC-MorseSignals-*' },
);
