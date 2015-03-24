use ExtUtils::MakeMaker;

WriteMakefile (
    NAME => 'Salvation::MongoMgr',
    VERSION_FROM => 'lib/Salvation/MongoMgr.pm',
    ABSTRACT => 'MongoDB monitoring & management helper library',
    AUTHOR => [ 'Gennadiy Filatov <gfilatov@cpan.org>' ],
    LICENSE => 'mit',
    PREREQ_PM => {
        JSON => 0,
        boolean => 0,
        MongoDB => 0,
        'List::MoreUtils' => 0,
        'Salvation::TC' => 0,
        'File::Slurp' => 0,
        'Getopt::Long' => 0,
    },
    META_MERGE => {
    "meta-spec" => { version => 2 },
        resources => {
            repository => {
                type => 'git',
                url => 'https://github.com/kainwinterheart/salvation-mongomgr.git',
                web => 'https://github.com/kainwinterheart/salvation-mongomgr',
                bugtracker => 'https://github.com/kainwinterheart/salvation-mongomgr/issues',
            },
        },
    },
);

exit 0;

__END__
