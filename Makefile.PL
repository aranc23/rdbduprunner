use 5.016003;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Backup::rdbduprunner',
    VERSION_FROM      => 'lib/Backup/rdbduprunner.pm', # finds $VERSION, requires EU::MM from perl >= 5.5
    PREREQ_PM         => {
        JSON => undef,
        'File::Basename' => undef,
        'Data::Dumper' => undef,
        'File::Spec' => undef,
        'File::Path' => undef,
        'AnyDBM_File' => undef,
        'Storable' => undef,
        'Readonly' => undef,
        'Config::General' => undef,
        'Config::Validator' => undef,
        'Config::Any' => undef,
        'Log::Dispatch' => undef,
        'Log::Dispatch::Screen' => undef,
        'Log::Dispatch::Syslog' => undef,
        'Log::Dispatch::File' => 0,
    },
    ABSTRACT_FROM     => 'lib/Backup/rdbduprunner.pm', # retrieve abstract from module
    AUTHOR            => 'Aran Cox <arancox@gmail.com>',
    "EXE_FILES" => [
        "rdbduprunner"
    ],
    #LICENSE           => 'perl',
    #Value must be from legacy list of licenses here
    #https://metacpan.org/pod/Module::Build::API
);
