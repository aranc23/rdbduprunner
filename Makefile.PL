use 5.016003;
use ExtUtils::MakeMaker;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME              => 'Backup::rdbduprunner',
    VERSION_FROM      => 'lib/Backup/rdbduprunner.pm', # finds $VERSION, requires EU::MM from perl >= 5.5
    PREREQ_PM         => {
        'AnyDBM_File' => 0,
        'Carp' => 0,
        'Clone' => 0,
        'Config::General' => 0,
        'Config::Validator' => 0,
        'Cpanel::JSON::XS' => 0,
        'Data::Dumper' => 0,
        'Data::UUID' => 0,
        'File::Basename' => 0,
        'File::Path' => 0,
        'File::Spec' => 0,
        'Hash::Merge' => 0,
        'IO::Interactive' => 0,
        'Log::Dispatch' => 0,
        'Log::Dispatch::File' => 0,
        'Log::Dispatch::Screen' => 0,
        'Log::Dispatch::Syslog' => 0,
        'Readonly' => 0,
        'Storable' => 0,
        'Sys::Hostname' => 0,
        'YAML::Syck' => 0,
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
