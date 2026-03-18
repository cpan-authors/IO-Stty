
use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME          => 'IO::Stty',
    AUTHOR        => 'Austin Schutz <auschutz@cpan.org>',
    VERSION_FROM  => 'lib/IO/Stty.pm',
    ABSTRACT_FROM => 'lib/IO/Stty.pm',
    PL_FILES      => {},
    ( $ExtUtils::MakeMaker::VERSION >= 6.3002 ? ( 'LICENSE' => 'perl', ) : () ),
    ( $ExtUtils::MakeMaker::VERSION >= 6.64 ? (
        TEST_REQUIRES => {
            'Test::More' => 0,
        },
    ) : (
        PREREQ_PM => {
            'Test::More' => 0,
        },
    )),
    dist  => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean => { FILES    => 'IO-Stty-*' },
    META_MERGE => {
        'meta-spec' => { version => 2 },
        resources => {
            license    => ['https://dev.perl.org/licenses/'],
            homepage   => 'https://github.com/cpan-authors/IO-Stty',
            bugtracker => {
                web => 'https://github.com/cpan-authors/IO-Stty/issues',
            },
            repository => {
                type => 'git',
                url  => 'https://github.com/cpan-authors/IO-Stty.git',
                web  => 'https://github.com/cpan-authors/IO-Stty',
            },
        },
    },
);
