package Backup::rdbduprunner;

use 5.016003;
use strict;
use warnings;

require Exporter;
use AutoLoader qw(AUTOLOAD);

# used for dispatcher
use Log::Dispatch;
use Log::Dispatch::Syslog;
use Log::Dispatch::Screen;
use Log::Dispatch::File;
use POSIX qw( strftime pause );
use POSIX ":sys_wait_h"; # for nonblocking read
use Readonly;
use Env qw( HOME DEBUG );
use Data::Dumper;
use File::Basename;
use File::Spec::Functions;
use File::Path qw(make_path);
use English qw( -no_match_vars );
use Getopt::Long qw(GetOptionsFromArray);
use Fcntl qw(:DEFAULT :flock); # import LOCK_* constants
use Storable qw( freeze thaw dclone );
use Scalar::Util qw/reftype looks_like_number/;
use GDBM_File;
eval { use Time::HiRes qw( time ); };
use Fatal qw( :void open close link unlink symlink rename fork );
# added from CPAN or system packages
use Config::General;
use Config::Validator;
use YAML::Syck;
use Cpanel::JSON::XS;
use Hash::Merge qw(merge);
use Clone qw(clone);
use Carp;
#from a standard perl distribution, on UNIX at least
use Pod::Usage;
use Sys::Hostname;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Backup::rdbduprunner ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
&create_dispatcher
&debug
&info
&notice
&_warning
&error
&critical
&alert
&emergency
&dlog
$EXIT_CODE
&verbargs
$STATE_DIR
$CONFIG_DIR
$LOCK_DIR
$LOG_DIR
%CONFIG
$RUNTIME
@BACKUPS
$APP_NAME
$LOG_FILE
$LOG_DIR
%config_definition
@INCREMENTS
&perform_backups
&parse_config_backups
&status_print
&status_json
&status_log
&status_prom
&status_delete
&backup_sort
&build_backup_command
&parse_argv
%DEFAULT_CONFIG
%CLI_CONFIG
&hashref_keys_drop
&hashref_key_array
&hashref_key_array_match
%children
&merge_config_definition
&find_configs
%databasetype_case
&stringy
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

our $VERSION = '1.8.6';

# constant name of the application
our $APP_NAME = 'rdbduprunner';

# from the man page for rsync 3.1.1
Readonly our $EXIT_CODE => {
    'rsync' => {
        '0'  => 'Success',
        '1'  => 'Syntax or usage error',
        '2'  => 'Protocol incompatibility',
        '3'  => 'Errors selecting input/output files, dirs',
        '4'  => 'Requested  action  not  supported',
        '5'  => 'Error starting client-server protocol',
        '6'  => 'Daemon unable to append to log-file',
        '10' => 'Error in socket I/O  Error in file I/O',
        '11' => 'Error in file I/O',
        '12' => 'Error in rsync protocol data stream',
        '13' => 'Errors with program diagnostics',
        '14' => 'Error in IPC code',
        '20' => 'Received SIGUSR1 or SIGINT',
        '21' => 'Some error returned by waitpid()',
        '22' => 'Error allocating core memory buffers',
        '23' => 'Partial transfer due to error',
        '24' => 'Partial transfer due to vanished source files',
        '25' => 'The --max-delete limit stopped deletions',
        '30' => 'Timeout in data send/receive',
        '35' => 'Timeout waiting for daemon connection',
    },
    'rdiff-backup' => {
        0 => 'Success',
        1 => 'ERROR', # anything with bit 1 set is an ERROR
        2 => 'WARNING', # anything with bit 2 set is a WARNING
    },
    'duplicity' => { 0 => 'Success' },
};

# translate lowercase database types to funky case
Readonly our %databasetype_case => (
    'mysql'      => 'MySQL',
    'postgresql' => 'PostgreSQL',
    'mongodb'    => 'MongoDB',
);

Readonly our %tag_priorities => (
    datetime          => -10,
    hostname          => -9,
    severity          => -8,
    msg               => -5,
    timestamp         => 50,
    host              => 2, # transformed by stringy
    tag               => 1, # transformed by stringy
    backupdestination => 10,
    dest              => 10,
    gtag              => 10,
    btype             => 10,
);

# supported config file extensions
Readonly our @extensions => qw( conf yaml json rc );

# we could use a list but regexp works in Validator
our $VALID_BACKUP_TYPE_REGEX = qr{^ ( rdiff [-] backup | rsync | duplicity ) $}xms;

# dispatcher needs a handle to write to:
our $DISPATCHER;

Readonly our $USER => $ENV{LOGNAME} || $ENV{USERNAME} || $ENV{USER} || scalar(getpwuid($<));

# configuring rdbduprunner:
Readonly our $STATE_DIR =>
    $USER eq 'root'                 ? File::Spec->catfile('/var/lib', $APP_NAME)
    : exists $ENV{'XDG_STATE_HOME'} ? File::Spec->catfile($ENV{'XDG_STATE_HOME'}, $APP_NAME)
    : exists $ENV{'HOME'}           ? File::Spec->catfile($ENV{'HOME'}, '.local', 'state', $APP_NAME)
    : undef;
Readonly our $LOCK_DIR => ($USER eq 'root' ? File::Spec->catfile('/run',$APP_NAME) : $STATE_DIR);
our $LOG_DIR = $USER eq 'root' ? File::Spec->catfile('/var/log',$APP_NAME) : $STATE_DIR;
Readonly our $DB_FILE => File::Spec->catfile($STATE_DIR, "${APP_NAME}.db");
Readonly our $DB_LOCK => join('.', File::Spec->catfile($LOCK_DIR,basename($DB_FILE)), 'lock');
Readonly our $LOG_FILE => File::Spec->catfile( $LOG_DIR, 'rdbduprunner.log' );
# can be overridden from the command line, but not the config
Readonly our $CONFIG_DIR =>
    $USER eq 'root'                  ? File::Spec->catfile('/etc',$APP_NAME)
    : exists $ENV{'XDG_CONFIG_HOME'} ? File::Spec->catfile($ENV{'XDG_CONFIG_HOME'}, $APP_NAME)
    : exists $ENV{'HOME'}            ? File::Spec->catfile($ENV{'HOME'}, '.config', $APP_NAME)
    : undef;

our %children; # store children for master backup loop
our $RUNTIME; # storing the start time so we can calculate run time

# read the config file into this hash:
our %CONFIG;
# read the command line options into this hash:
our %CLI_CONFIG;
# create this list of hashes, with each one corresponding to an
# invocation of a backup program that needs to be run:
our @BACKUPS;
our @INCREMENTS;

our %DEFAULT_CONFIG = (
    # this affects what is logged as well as output to the terminal so
    # setting it everywhere seems acceptable:
    'stats' => {
        default  => 1,
        getopt   => 'stats!',
        type     => "valid(truefalse)",
        optional => "true",
        sections => [qw(cli global backupdestination backupset)],
    },
    'wholefile' => {
        'getopt' => 'wholefile|whole-file|whole_file!',
        type     => "valid(truefalse)",
        optional => "true",
        sections => [qw(cli global backupdestination backupset)],
    },
    'inplace' => {
        getopt   => 'inplace!',
        type     => "valid(truefalse)",
        default  => 0,
        optional => "true",
        sections => [qw(cli global backupdestination backupset)],
    },
    'sparse' => {
        getopt   => 'sparse!',
        type     => "valid(truefalse)",
        default  => 1,
        optional => "true",
        sections => [qw(cli global backupdestination backupset)],
    },
    'checksum' => {
        getopt   => 'checksum|c!',
        type     => "valid(truefalse)",
        default  => 0,
        optional => "true",
        sections => [qw(cli global backupdestination backupset)],
    },
    # because this affects the log output of rdiff-backup it should be
    # settable across levels
    'verbosity' => {
        getopt   => 'verbosity=i',
        type     => "integer",
        optional => "true",
        sections => [qw(cli global backupdestination backupset)],
    },
    # only used on rdiff-backup, only affects terminal output
    'terminalverbosity' => {
        getopt   => 'terminalverbosity|tverbosity|t|terminal-verbosity=i',
        type     => "integer",
        optional => "true",
        sections => [qw(cli)],
    },
    'verbose' => {
        getopt   => 'verbose|v!',
        type     => "valid(truefalse)",
        optional => "true",
        default  => 0,
        sections => [qw(cli)],
    },
    'progress' => {
        getopt   => 'progress!',
        type     => "valid(truefalse)",
        optional => "true",
        default  => 0,
        sections => [qw(cli)],
    },
    # seems specific to rdiff-backup, where compression is enabled by default:
    'sshcompress' => {
        getopt   => 'sshcompress!',
        type     => "valid(truefalse)",
        optional => "true",
        sections => [qw(cli global backupdestination backupset)],
    },
    'maxprocs' => {
        getopt   => 'maxprocs=i',
        type     => "integer",
        optional => "true",
        min      => 1,
        default  => 1,
        sections => [qw(cli global)],
    },
    'facility' => {
        getopt   => 'facility=s',
        default  => 'user',
        type     => "string",
        optional => "true",
        sections => [qw(cli global)],
        match    => qr{^(auth|authpriv|cron|daemon|kern|local[0-7]|mail|news|syslog|user|uucp)$},
    },
    'level' => {
        getopt   => 'level|log-level|log_level=s',
        default  => 'info',
        type     => "string",
        optional => "true",
        sections => [qw(cli global)],
        match => qr{^(debug|info|notice|warning|error|critical|alert|emergency)$},
    },
    # duplicity options, so who cares
    lc "GPGPassPhrase" => {
        type     => "string",
        optional => "true",
        sections => [qw(global backupdestination)],
    },
    lc "AWSAccessKeyID" => {
        type     => "string",
        optional => "true",
        sections => [qw(global backupdestination)],
    },
    lc "AWSSecretAccessKey" => {
        type     => "string",
        optional => "true",
        sections => [qw(global backupdestination)],
    },
    lc "SignKey" => {
        type     => "string",
        optional => "true",
        sections => [qw(global backupdestination)],
    },
    lc "EncryptKey" => {
        type     => "string",
        optional => "true",
        sections => [qw(global backupdestination)],
    },

    # uses --bwlimit on rsync and trickly binary on others:
    lc "Trickle" => {
        getopt   => 'trickle=i',
        type     => "integer",
        optional => "true",
        "min"    => 1,
        sections => [qw(cli global backupdestination backupset)],
    },

    # zfs options
    lc "ZfsCreate" => {
        type     => "valid(truefalse)",
        optional => "true",
        sections => [qw(global backupdestination)],
        },
    lc "ZfsSnapshot" => {
        type     => ['boolean',"valid(truefalse)"],
        optional => "true",
        sections => [qw(global backupdestination)],
    },
    'full' => {
        getopt   => 'full!',
        type     => "valid(truefalse)",
        optional => "true",
        sections => [qw(cli)],
    },
    'force' => {
        getopt   => 'force!',
        type     => "valid(truefalse)",
        optional => "true",
        sections => [qw(cli)],
    },
    # the following changes the major mode of operation for rdbduprunner:
    # 'calculate-average'      => \$AVERAGE,
    'average' => {
        getopt => 'average|calculate-average',
        type     => "valid(truefalse)",
        optional => "true",
        sections => [qw(cli)],
        mode     => \&average_mode,
    },
    # 'cleanup'                => \$CLEANUP,
    # 'check'                  => \$CLEANUP,
    'cleanup' => {
        getopt => 'cleanup|check',
        type     => "valid(truefalse)",
        optional => "true",
        sections => [qw(cli)],
        mode     => \&cleanup_mode,
    },
    # 'compare'                => \$COMPARE,
    # 'verify'                 => \$COMPARE,
    'compare' => {
        getopt => 'compare|verify',
        type     => "valid(truefalse)",
        optional => "true",
        sections => [qw(cli)],
        mode     => \&compare_mode,
    },
    # 'dump'                   => \$DUMP,
    'dump' => {
        getopt   => 'dump',
        type     => "valid(truefalse)",
        optional => "true",
        sections => [qw(cli)],
        mode     => \&dump_mode,
    },
    # 'list-oldest'            => \$LISTOLDEST,
    'listoldest' => {
        getopt   => 'listoldest|list-oldest',
        type     => "valid(truefalse)",
        optional => "true",
        sections => [qw(cli)],
        mode     => \&listoldest_mode,
    },
    # 'remove-oldest'          => \$REMOVE,
    'remove' => {
        getopt   => 'remove|remove-oldest',
        type     => "valid(truefalse)",
        optional => "true",
        sections => [qw(cli)],
        mode     => \&remove_mode,
    },
    # 'status'                 => \$STATUS,
    'status' => {
        getopt   => 'status',
        type     => "valid(truefalse)",
        optional => "true",
        sections => [qw(cli)],
        mode     => \&status_mode,
    },
    # 'tidy'                   => \$TIDY,
    'tidy' => {
        getopt => 'tidy',
        type     => "valid(truefalse)",
        optional => "true",
        sections => [qw(cli)],
        mode     => \&tidy_mode,
    },
    # 'list'                   => \$LIST,
    'list' => {
        getopt => 'list',
        type     => "valid(truefalse)",
        optional => "true",
        sections => [qw(cli)],
        mode     => \&list_mode,
    },
    # 'orphans'                => \$ORPHANS,
    'orphans' => {
        getopt => 'orphans',
        type     => "valid(truefalse)",
        optional => "true",
        sections => [qw(cli)],
        mode     => \&orphans_mode,
    },
    # maintain/view the status database:
    'status_json' => {
        getopt => 'status_json|status-json',
        type     => "valid(truefalse)",
        optional => "true",
        sections => [qw(cli)],
        mode     => \&status_json,
    },
    'status_print' => {
        getopt => 'status_print|status-print',
        type     => "valid(truefalse)",
        optional => "true",
        sections => [qw(cli)],
        mode     => \&status_print,
    },
    'status_log' => {
        getopt => 'status_log|status-log',
        type     => "valid(truefalse)",
        optional => "true",
        sections => [qw(cli)],
        mode     => \&status_log,
    },
    'status_prom' => {
        getopt => 'status_prom|status-prom',
        type     => "valid(truefalse)",
        optional => "true",
        sections => [qw(cli)],
        mode     => \&status_prom,
    },
    # 'status_delete|status-delete=s@' => \@STATUS_DELETE,
    'status_delete' => {
        getopt => 'status_delete|status-delete=s@',
        type     => "list?(string)",
        optional => "true",
        sections => [qw(cli)],
        mode     => \&status_delete,
    },
    #'duplicity-binary=s'     => \$DUPLICITY_BINARY,
    'duplicitybinary' => {
        getopt => 'duplicitybinary|duplicity-binary=s',
        default => 'duplicity',
        type     => "string",
        optional => "true",
        sections => [qw(cli global backupdestination backupset)],
    },
    # 'rdiff-backup-binary=s'  => \$RDIFF_BACKUP_BINARY,
    lc 'RdiffBackupBinary' => {
        getopt => 'rdiffbackupbinary|rdiff-backup-binary=s',
        default => 'rdiff-backup',
        type     => "string",
        optional => "true",
        sections => [qw(cli global backupdestination backupset)],
    },
    # 'rsync-binary=s'         => \$RSYNC_BINARY,
    'rsyncbinary' => {
        getopt => 'rsyncbinary|rsync-binary=s',
        default => 'rsync',
        type     => "string",
        optional => "true",
        sections => [qw(cli global backupdestination backupset)],
    },
    #'zfs-binary=s'           => \$ZFS_BINARY,
    'zfsbinary' => {
        getopt => 'zfsbinary|zfs-binary=s',
        default => 'zfs',
        type     => "string",
        optional => "true",
        sections => [qw(cli global backupdestination backupset)],
    },
    'tricklebinary' => {
        getopt => 'tricklebinary|trickle-binary=s',
        default => 'trickle',
        type     => "string",
        optional => "true",
        sections => [qw(cli global backupdestination backupset)],
    },
    # 'maxwait=i'              => \$MAXWAIT,
    maxwait => {
        getopt => 'maxwait=i',
        default => 86400,
        type => "integer",
        min => 1,
        optional => "true",
        sections => [qw(cli global)],
    },
    # only valid for duplicity/rdiff-backup types
    maxinc => {
        getopt   => 'maxinc=i',
        type     => "integer",
        min      => 0,
        optional => "true",
        sections => [qw(cli global backupdestination backupset)],
    },
    maxage => {
        getopt => 'maxage=s',
        type => "string",
        optional => "true",
        sections => [qw(cli global backupdestination backupset)],
        match => qr{^(\d+[smhDWMY]){1,}$},
    },
    'skipfstype' => {
        getopt   => 'skipfstype|skipfs=s@',
        type     => 'list?(string)',
        optional => "true",
        sections => [qw(cli global backupdestination backupset)],
        default  => [qw(
            autofs
            binfmt_misc
            bpf
            cgroup
            cgroup2
            cifs
            configfs
            debugfs
            devpts
            devtmpfs
            efivarfs
            exfat
            fuse
            fuse.encfs
            fuse.glusterfs
            fuse.gvfs-fuse-daemon
            fuse.gvfsd-fuse
            fuse.lxcfs
            fuse.portal
            fuse.sshfs
            fuse.vmware-vmblock
            fuse.xrdp-chansrv
            fuseblk
            fusectl
            htfs
            hugetlbfs
            ipathfs
            iso9660
            mqueue
            nfs
            nfs4
            nfsd
            nsfs
            ntfs
            proc
            pstore
            rootfs
            rpc_pipefs
            securityfs
            selinuxfs
            squashfs
            sysfs
            tmpfs
            tracefs
            usbfs
            vfat
            zfs
                   )],
    },
    allowfs => {
        getopt   => 'allowfs=s@',
        type     => 'list?(string)',
        optional => "true",
        sections => [qw(cli global backupdestination backupset)],
    },

    skip => {
        getopt => 'skip=s@',
        type => "list?(string)",
        optional => "true",
        sections => [qw(cli global backupdestination backupset)],
    },
    skipre => {
        getopt => 'skipre=s@',
        type => "list?(string)",
        optional => "true",
        sections => [qw(cli global backupdestination backupset)],
    },
    # 'localhost=s'            => \$LOCALHOST,
    localhost => {
        getopt => 'localhost=s',
        type => "string",
        optional => "true",
        sections => [qw(cli global )],
        default => shortname(),
    },
    #$USEAGENT and push(@com,'--use-agent');
    useagent => {
        getopt => 'useagent|use-agent|u',
        type => "valid(truefalse)",
        optional => "true",
        sections => [qw(cli global backupdestination backupset)],
    },
    #$ALLOWSOURCEMISMATCH and push(@com,'--allow-source-mismatch');
    lc "AllowSourceMismatch" => {
        getopt => 'allowsourcemismatch|allow-source-mismatch',
        type => "valid(truefalse)",
        optional => "true",
        sections => [qw(cli)],
    },
    'test' => {
        getopt => 'test!',
        type => "valid(truefalse)",
        optional => "true",
        sections => [qw(cli)],
        default => 1,
    },
    #'exclude-path=s'         => \$EXCLUDE_PATH,
    'excludepath' => {
        getopt => 'excludepath|exclude-path=s',
        type => "string",
        optional => "true",
        default => '/etc/rdbduprunner',
        sections => [qw(cli global)],
    },
    tempdir => {
        getopt => 'tempdir|temp-dir=s',
        type => "string",
        optional => "true",
        sections => [qw(cli global)],
    },
    'dryrun' => {
        getopt => 'dryrun|dry-run|n',
        type => "valid(truefalse)",
        optional => "true",
        sections => [qw(cli)],
    },
    # show usage
    #'h|help'                 => \$HELP,
    'help' => {
        getopt => 'help|h',
        type => "valid(truefalse)",
        optional => "true",
        sections => [qw(cli)],
    },
    # can be overridden from the command line, but not the config
    # 'config=s'               => \$CONFIG_FILE, # config file
    'config' => {
        getopt => 'config|config-file|config_file=s@',
        type => "list?(string)",
        optional => "true",
        sections => [qw(cli)],
    },
    'confd' => {
        getopt   => 'confd|conf-d|conf_d=s',
        type     => "string",
        optional => "true",
        sections => [qw(cli)],
    },
    # the next three options limit which backups get acted upon
    #'dest=s'                 => \$DEST,
    #'host=s'                 => \$HOST,
    #'path=s'                 => \$PATH,
    'filterdest' => {
        getopt => 'filterdest|dest=s',
        type => "string",
        optional => "true",
        sections => [qw(cli)],
    },
    'filterpath' => {
        getopt => 'filterpath|path=s',
        type => "string",
        optional => "true",
        sections => [qw(cli)],
    },
    'filterhost' => {
        getopt => 'filterhost|host=s',
        type => "string",
        optional => "true",
        sections => [qw(cli)],
    },
    prerun => {
        type => "string",
        optional => "true",
        sections => [qw(global backupdestination backupset)],
    },
    postrun => {
        type => "string",
        optional => "true",
        sections => [qw(global backupdestination backupset)],
    },
    volsize => {
        getopt   => 'volsize=i',
        type     => "integer",
        min      => 1,
        optional => "true",
        sections => [qw(cli global backupdestination backupset)],
    },
);

our %config_definition = (
    backupset => {
        type   => 'struct',
        fields =>
        {
            # setting the tag only makes sense when inventory is false
            # and path is specified only once:
            tag => {
                type => "string",
                optional => "true",
                # validate this... it must be able to be used as a
                # directory name and possibly the name of a zfs as
                # well
            },
            host => {
                type => ["hostname","ipv4","ipv6"],
                optional => "true",
            },
            # must match an existing backupdestion,
            # required unless global defaultbackupdestination is set
            backupdestination => {
                type => "string",
                optional => "true",
            },
            # required if inventory is false
            path =>
            { type => "list?(string)", optional => "true" },
            exclude =>
            { type => "list?(string)", optional => "true" },
            disabled => {
                type => "valid(truefalse)",
                optional => "true"
            },
            inventory => {
                type => "valid(truefalse)",
                optional => "true"
            },

        },
    },
    backupdestination => {
        type   => 'struct',
        fields =>
        {
            # this is only optional because the default is rsync:
            type => {
                type => "string",
                optional => "true",
                match => $VALID_BACKUP_TYPE_REGEX,
            },
            busted => {
                type => "valid(truefalse)",
                optional => "true"
            },
            # this is the only require parameter, and is the output
            # path or url of the destination for the this backup:
            path =>
            { type => "string" },
            # only valid for duplicity/rdiff-backup types
            percentused => {
                type     => "integer",
                min      => 0,
                max      => 100,
                optional => "true",
            },
            # only valid for duplicity/rdiff-backup types, expressed in 512B blocks
            minfree => {
                type     => "integer",
                min      => 0,
                optional => "true",
            },
        },
    },
    truefalse => {
        type => 'string',
        match => qr{^(?:on|off|true|false|0|1|yes|no|t|f)$}xmsi,
    },
    cli => {
        type   => 'struct',
        fields => { },
    },
    global => {
        type   => 'struct',
        fields => {
            defaultbackupdestination =>
                { type => "string", optional => "true" },
            backupdestination => {
                type     => 'table(valid(backupdestination))',
                optional => "true",
            },
            backupset => {
                type     => 'table(valid(backupset))',
                optional => "true",
            },
        },
    },
);

our %config_load_dispatch = (
    'conf' => \&load_config_conf,
    'rc'   => \&load_config_conf,
    'yaml' => \&load_config_yaml,
    'json' => \&load_config_json,
);

my $callback_clean = sub { my %t=@_;
                           chomp $t{message};
                           return $t{message}."\n"; # add a newline
                         };
sub create_dispatcher {
    my ( $IDENT, $FACILITY, $LOG_LEVEL, $LOG_FILE ) = @_;
    print STDERR Data::Dumper->Dump([$IDENT, $FACILITY, $LOG_LEVEL, $LOG_FILE],
                                    [qw(ident facility log_level log_file)]) if $DEBUG;

    $DISPATCHER = Log::Dispatch->new( callbacks => $callback_clean );

    $DISPATCHER->add(
        Log::Dispatch::Syslog->new(
            name      => 'syslog',
            min_level => $LOG_LEVEL,
            ident     => $IDENT . '[' . $$ . ']',
            facility  => $FACILITY,
            socket    => 'unix',
        )
    );

    $DISPATCHER->add(
        Log::Dispatch::Screen->new(
            name      => 'screen',
            min_level => $LOG_LEVEL,
            stderr    => 0,
        )
    );
    $DISPATCHER->add(
        Log::Dispatch::File->new(
            name      => 'logfile',
            min_level => $LOG_LEVEL,
            filename  => $LOG_FILE,
            mode      => '>>',
        )
    );
}

sub debug {
  $DISPATCHER->debug(@_);
}
sub info {
  $DISPATCHER->info(@_);
}
sub notice {
  $DISPATCHER->notice(@_);
}
sub _warning {
  $DISPATCHER->warning(@_);
}
sub error {
  $DISPATCHER->error(@_);
}
sub critical {
  $DISPATCHER->critical(@_);
}
sub alert {
  $DISPATCHER->alert(@_);
}
sub emergency {
  $DISPATCHER->emergency(@_);
}

sub dlog {
  my $level = shift;
  my $msg   = shift;
  my $time  = time();
  my $str   = stringy({'msg'      => $msg,
                       'severity' => $level,
                       timestamp  => $time,
                       datetime   => POSIX::strftime("%FT%T%z",localtime($time))},
                      @_);
  $DISPATCHER->log( level   => $level,
                    message => $str,
                  );
  return $str;
}

# string turns hash refs into a string of key value pairs, it does not recurse
sub stringy {
  # each element passed to stringy should be a HASH REF
  my %a; # strings
  my %specials  = (
      tag => 1,
      host => 1,
  );
  foreach my $h (@_) {
    next unless ref $h eq 'HASH';
    while( my ($key,$val) = each(%$h) ) {
      next if ref $val; # must not be a reference
      $val =~ s/\n/NL/g; # remove newlines
      $val =~ s/"/\\"/g; # replace " with \"
      if ($key =~ /^pass/) {
        $val = 'XXXXXXXX';
      } elsif( $key eq 'databasetype' and defined $databasetype_case{$val}) {
        $val = $databasetype_case{$val};
      } elsif( $key eq 'runtime' or $key eq 'total_run_time_seconds' ){
          $val = sprintf("%.5f", $val);
      }
      if($specials{$key}) {
        $a{"${APP_NAME}_${key}"}=$val;
      } else {
        $a{$key}=$val;
      }
    }
  }
  my @f;
  foreach my $key (sort {&sort_tags} (keys(%a))) {
    push(@f,"${key}=\"$a{$key}\"");
  }
  return join(" ",@f);
}

# sort function, use the priority of a tag to compare,
# otherwise use string compare (alphabetical)
sub sort_tags {
    my $p = tag_prio($a) <=> tag_prio($b);
    if ( $p == 0 ) {
        return $a cmp $b;
    }
    return $p;
}

# look up the priority in the table, return 0 otherwise
sub tag_prio {
  my $t=lc $_[0];
  return $tag_priorities{$t} if defined $tag_priorities{$t};
  return 0;
}

sub verbargs {
  my $bh=$_[0];
  my @a;
  if($$bh{btype} ne 'rsync') {
    if(defined $$bh{verbosity}) {
      push(@a,'--verbosity',$$bh{verbosity});
    }
    if(defined $$bh{terminalverbosity} and $$bh{btype} eq 'rdiff-backup') {
      push(@a,'--terminal-verbosity',$$bh{terminalverbosity});
    }
  }
  else {
    if(dtruefalse($bh,'progress')) {
      push(@a,'--progress');
    }
    if(dtruefalse($bh,'verbose')) {
      push(@a,'--verbose');
    }
  }
  return(@a);
}

sub build_backup_command {
  my $bh=shift;
  my @com;
  if(dtruefalse($bh,'disabled')) {
    dlog('notice','disabled backup',$bh);
    # skip disabled backups
    return;
  }

  if($$bh{btype} eq 'duplicity' and not -d $$bh{path}) {
    dlog('warning','path does not exist',$bh);
    _warning("backup path $$bh{path} does not exist for $$bh{tag}: skipping this backup");
    return;
  }

  if($$bh{btype} eq 'duplicity') {
    @com=($$bh{duplicitybinary});
    push(@com,'full') if dtruefalse(\%CLI_CONFIG, 'full');
    if(dtruefalse($bh,'dryrun')) {
      push(@com,'--dry-run');
    }
    $$bh{volsize} and push(@com, '--volsize', $$bh{volsize});
    dtruefalse($bh,'useagent') and push(@com,'--use-agent');
    dtruefalse($bh,'allowsourcemismatch') and push(@com,'--allow-source-mismatch');
    if(defined $$bh{signkey}) {
      push(@com,'--sign-key',$$bh{signkey});
    }
    if(defined $$bh{encryptkey}) {
      push(@com,'--encrypt-key',$$bh{encryptkey});
    }
    unless(dtruefalse($bh,'stats')) {
      push(@com,'--no-print-statistics');
    }
    push(@com,'--exclude-other-filesystems');
  } elsif($$bh{btype} eq 'rdiff-backup') { # must be rdiff-backup
    @com=($$bh{rdiffbackupbinary},
          '--exclude-device-files',
          '--exclude-other-filesystems',
          '--no-eas',
         );
    unless(dtruefalse($bh,'sshcompress')) {
      push(@com,'--ssh-no-compression');
    }
    if(dtruefalse($bh,'stats')) {
      push(@com,'--print-statistics');
    }
  } elsif($$bh{btype} eq 'rsync') {
    @com=($$bh{rsyncbinary},
          '--archive',
          '--one-file-system',
          '--hard-links',
          '--delete',
          '--delete-excluded',
         );
    # here is the where the rubbger meets the robe:
    if( defined $$bh{wholefile}) {
      push(@com, dtruefalse($bh,'wholefile') ? '--whole-file' : '--no-whole-file');
    }
    if(dtruefalse($bh,'dryrun')) {
      push(@com,'--dry-run');
    }
    if(dtruefalse($bh,'checksum')) {
      push(@com,'--checksum');
    }
    if(dtruefalse($bh,'inplace')) {
      push(@com,'--inplace','--partial');
    }
    if(dtruefalse($bh,'sparse')) {
      push(@com,'--sparse');
    }
    if(defined $$bh{trickle} and $$bh{trickle} =~ /^\d+$/) {
      push(@com,"--bwlimit=$$bh{trickle}");
    }
    if(dtruefalse($bh,'sshcompress')) {
      push(@com,'-z');
    }
    if(dtruefalse($bh,'stats')) {
      push(@com,'--stats');
    }
    # use logging
    push(@com,'--log-file='.catfile($LOG_DIR,$$bh{tag}).'.log')
  }

  if(defined $$bh{tempdir}) {
      if(-d $$bh{tempdir}) {
        if($$bh{btype} eq 'rsync') {
            push(@com,"--temp-dir=$$bh{tempdir}");
        } else {
            push(@com,'--tempdir',$$bh{tempdir});
        }
    } else {
        warn("specified temporary directory does not exist, not using it: $$bh{tempdir}");
    }
  }
  unshift(@com,shift @com,verbargs($bh));

  foreach my $f (@{$$bh{excludes}}) {
    if($$bh{btype} eq 'rsync') {
      push(@com,"--exclude-from=$f");
    } else { # rdiff-backup and duplicity
      push(@com,'--exclude-globbing-filelist',
           $f);
    }
  }
  foreach my $x (@{$$bh{exclude}}) {
    push(@com,'--exclude',$x);
  }
  push(@com,$$bh{src},$$bh{dest});

  # if Trickle is set for a destination, use the trickle binary to slow upload rates to the value given
  if(defined $$bh{trickle} and $$bh{trickle} =~ /^\d+$/ and $$bh{btype} ne 'rsync') {
    unshift(@com,$$bh{tricklebinary},'-s','-u',$$bh{trickle});
  }
  return @com;
}

sub hash_backups {
  my %h;
  foreach my $bh (@_) {
    push(@{$h{$$bh{host}}},$bh);
  }
  return %h;
}

sub perform_backups {
  my %BACKUPS = hash_backups(@_);
  $SIG{CHLD} = sub {
    # don't change $! and $? outside handler
    local ($!, $?);
    while ( (my $pid = waitpid(-1, WNOHANG)) > 0 ) {
      debug("waitpid returned child ${pid}");
      delete $children{$pid};
    }
  };
  do {
    while ( (my $pid = waitpid(-1, WNOHANG)) > 0 ) {
      debug("waitpid returned child ${pid}");
      delete $children{$pid};
    }
    my $maxprocs = key_selector('maxprocs');
    die unless $maxprocs;

    while ( scalar(keys(%children)) < $maxprocs
            and scalar(keys(%BACKUPS)) > 0 ) {
      my $host=(keys %BACKUPS)[0];
      my $list=$BACKUPS{$host};
      debug("about to spawn sub-process for ${host}");
      delete $BACKUPS{$host};
      my $pid=fork();
      if ($pid == 0) {
        delete $SIG{CHLD};
        undef %children; # we don't have children
        perform_backup($host,@{$list});
        critical('perform_backup should never return');
        exit;
      } elsif ($pid > 0) {
        debug("added child to children hash: ${pid}");
        $children{$pid}=$list;
      }
    }
    if (scalar(keys(%children)) > 0) {
      debug('waiting on '.(scalar(keys(%children))).' sub-processes to exit, '.scalar(keys(%BACKUPS)).' more children to spawn, pausing');
      my $pause_start=time();
      pause;
      debug("paused for: ".sprintf('%.2f seconds',time()-$pause_start));
    }
  } until scalar(keys(%children)) == 0 and scalar(keys(%BACKUPS)) == 0
}

sub perform_backup {
  my $host=shift;
  # to set the pid, may not work correctly
  create_dispatcher(
      $APP_NAME,
      key_selector('facility'),
      key_selector('level'),
      $LOG_FILE
  );
  my $lock1;
  # store the results of each backup in this hash:
  # like { '/var', 'failure', 1684884888 )
  unless($CLI_CONFIG{test}) {
    unless ($lock1=lock_pid_file($host)) {
      dlog('error','lock failure',$_[0]);
      exit;
    }
  }
 BACKUP:
  foreach my $bh (sort backup_sort (@_)) {
    foreach my $key (qw( src dest tag path host ) ) {
      my $env_var = join('_',uc($APP_NAME),'BACKUP',uc($key));
      if ( exists $$bh{$key} ) {
        $ENV{$env_var}=$$bh{$key};
      }
      elsif ( exists $ENV{$env_var} ) {
        delete $ENV{$env_var};
      }
    }

    if(defined $CONFIG{'backupdestination'}{$$bh{backupdestination}}
       and dtruefalse($CONFIG{'backupdestination'}{$$bh{backupdestination}},'busted')) {
      dlog('notice','skipping backup due to busted destination',$bh);
      next;
    }
    push(@{$$bh{com}},build_backup_command($bh));
    unless (@{$$bh{com}} > 0) {
      dlog('debug','empty backup command',$bh);
      next BACKUP;
    }
    if (dtruefalse($bh,'zfscreate') and not dtruefalse($bh,'dryrun')) {
      # this seems messy, but we want the parent dir of the real destination
      my @all_dirs = File::Spec->splitdir( $$bh{'dest'} );
      my $zfs_child = pop @all_dirs;
      my $zfs_parent = File::Spec->catdir( @all_dirs );
      if(-d $$bh{'dest'}) {
        debug("skipping zfs creation, directory exists: ".$$bh{'dest'});
      }
      elsif(my $zfs=which_zfs($zfs_parent)) {
        my @com=($$bh{zfsbinary},
                 'create',
                 "${zfs}/${zfs_child}",
                );
        info(join(' ',@com));
        unless($CLI_CONFIG{test}) {
          set_env($bh);
          system(@com);
          my $exit_status = exit_status(${^CHILD_ERROR_NATIVE});
          unless($exit_status == 0) {
            # if we failed to run the pre-run, issue the final summary based on that
            error("unable to execute zfs create command as requested: skipping backup!");
            update_status_db(
                $$bh{src},
                {   'phase' => 'zfscreate',
                    'exit'  => $exit_status,
                    'time'  => time(),
                    'btype' => $$bh{btype},
                }
            ) unless $CLI_CONFIG{test};
            log_exit_status($bh,$exit_status);
            next BACKUP;
          }
        }
      }
      else {
        my $msg = "unable to execute zfs create command as requested: skipping backup!";
        error( $msg );
        update_status_db(
            $$bh{src},
            {   'phase' => 'zfscreate',
                'exit'  => int(1),
                'errno' => $msg,
                'time'  => time(),
                'btype' => $$bh{btype},
            }
        ) unless $CLI_CONFIG{test};
        log_exit_status( $bh, int(1) );
        next;
      }
    }
    if (defined $$bh{prerun} and not $$bh{dryrun}) {
      info($$bh{prerun});
      unless($CLI_CONFIG{test}) {
        set_env($bh);
        system($$bh{prerun});
        my $exit_status = exit_status(${^CHILD_ERROR_NATIVE});
        unless ( $exit_status == 0 ) {
            # if we failed to run the pre-run, issue the final summary based on that
            my $msg = "unable to execute prerun command: skipping backup!";
            error($msg);
            update_status_db(
                $$bh{src},
                {   'phase' => 'prerun',
                    'exit'  => $exit_status,
                    'errno' => $msg,
                    'time'  => time(),
                    'btype' => $$bh{btype},
                }
            ) unless $CLI_CONFIG{test};
            log_exit_status( $bh, $exit_status );
            next;
        }
      }
    }
    info(join(" ",@{$$bh{com}}));
    my $mainret=0;
    unless($CLI_CONFIG{test}) {
      set_env($bh);
      $$bh{runtime}=time();
      system(@{$$bh{com}});
      $mainret = exit_status(${^CHILD_ERROR_NATIVE});
      $$bh{runtime}=time()-$$bh{runtime};
      if (defined $$EXIT_CODE{$$bh{btype}}{$mainret}) {
        $$bh{'exit_code'}=$$EXIT_CODE{$$bh{btype}}{$mainret};
      }
      unless($mainret == 0) {
        error("$$bh{btype} exited with error code!");
      }
    }
    # if there is no postrun, return the log_exit_status using $mainret
    # if there is a postrun, return that value instead regardless of failure
    if (defined $$bh{postrun} and not $$bh{dryrun}) {
      info($$bh{postrun});
      unless($CLI_CONFIG{test}) {
        set_env($bh);
        system( $$bh{postrun} );
        my $exit_status = exit_status(${^CHILD_ERROR_NATIVE});
        unless ( $exit_status == 0 ) {
            my $msg = "postrun command exited with an error";
            error($msg);

            # issue final summary based on the return value of the postrun command
            update_status_db(
                $$bh{src},
                {   'phase' => 'postrun',
                    'exit'  => $exit_status,
                    'errno' => $msg,
                    'time'  => time(),
                    'btype' => $$bh{btype},
                }
            ) unless $CLI_CONFIG{test};
            log_exit_status( $bh, $exit_status );
            next;
        }
      }
    }
    # attempt to create a snapshot of the destination filesystem
    if (defined $$bh{zfssnapshot} and bool_parse($$bh{zfssnapshot}) == 1 and not $$bh{dryrun}) {
      # zfs is path minus leading /
      if(my $zfs = find_zfs($$bh{'dest'})) {
        # snapshot is zfs plus a name
        my $snap=$zfs.'@rdbduprunner-'.( $mainret == 0 ? 'success-' : 'failure-').strftime("%FT%T%z",localtime());
        # snapshot commmand is straightforward
        my @com=($$bh{zfsbinary},
                 'snapshot',
                 $snap);
        info(join(' ',@com));
        unless($CLI_CONFIG{test}) {
          set_env($bh);
          # execute snapshot command
          system(@com);
          unless($? == 0) {
            error("zfs snapshot command exited with an error, this is not fatal: $?");
          }
        }
      }
      else {
        debug('skipping zfs snapshot, destination is not a zfs');
      }
    }
    # issue final summary based on the main backup process
    update_status_db(
        $$bh{src},
        {   'phase'   => 'backup',
            'exit'    => int($mainret),
            'errno'   => exists $$bh{exit_code} ? $$bh{exit_code} : 'backup failed',
            'time'    => time(),
            'runtime' => $$bh{runtime},
            'btype'   => $$bh{btype},
        }
    ) unless $CLI_CONFIG{test};
    log_exit_status($bh,$mainret) unless $CLI_CONFIG{test};
  }
  exit;
}
sub lock_db {
    my $flags = shift;
    $flags = LOCK_EX unless $flags;
    my $db_lock_handle;

    unless ( open($db_lock_handle, '>', $DB_LOCK) ) {
        error("unable to open database file ${DB_LOCK}");
        return;
    }
    unless ( flock( $db_lock_handle, LOCK_EX ) ) {
        error("unable to lock database file ${DB_LOCK}");
        return;
    }
    return $db_lock_handle;
}

sub unlock_db {
    flock($_[0],LOCK_UN);
    close($_[0]);
}

# update the state database
sub update_status_db {
    my ($src, $hash) = @_;
    my $db_file = File::Spec->catfile($STATE_DIR, "${APP_NAME}.db");
    my $db_lock_file = "${db_file}.lock";

    my $db_lock_handle = lock_db();

    my %status;
    unless(tie %status, 'GDBM_File', $db_file, O_CREAT|O_RDWR, 0666) {
        error("unable to open database file ${db_file}");
        return;
    }

    if ( exists $status{$src} and ref thaw($status{$src}) eq 'HASH') {
        my $h = thaw($status{$src});
        while( my ($k,$v) = each(%$hash) ) {
            $$h{$k} = $v;
        }
        for my $kk (qw( success failure )) {
            delete $$h{$kk} if exists $$h{$kk};
        }
        $status{$src} = freeze($h);
    }
    else {
        $status{$src} = freeze($hash);
    }
    untie %status;
    unlock_db($db_lock_handle);
    my $_msg = dlog('notice','backup status',
                    {'src' => $src},
                    $hash);
}

sub status_delete {
    my $h = lock_db(LOCK_EX);

    my %status;
    unless(tie %status, 'GDBM_File', $DB_FILE, O_RDWR, 0666) {
        error("unable to open database file ${DB_FILE} for deletions");
        return;
    }

    for my $k (@{$CLI_CONFIG{status_delete}}) {
        delete $status{$k} if exists $status{$k};
    }

    untie %status;
    unlock_db($h);
}

sub status_json {
    my $h = lock_db(LOCK_SH);

    my %status;
    unless(tie %status, 'GDBM_File', $DB_FILE, O_RDONLY, 0666) {
        error("unable to open database file ${DB_FILE} for reading");
        return;
    }

    my %json;
    while(my ($k,$v)=each(%status)) {
        $json{$k}=thaw($v);
    }
    print Cpanel::JSON::XS->new->ascii->pretty->allow_nonref->encode(\%json);
    untie %status;
    unlock_db($h);
}

sub status_print {
    my $h = lock_db(LOCK_SH);

    my %status;
    unless(tie %status, 'GDBM_File', $DB_FILE, O_RDONLY, 0666) {
        error("unable to open database file ${DB_FILE} for reading");
        return;
    }

    while(my ($k,$v)=each(%status)) {
        my $s = thaw($v);
        print $k;
        foreach my $k (qw( phase time exit errno runtime )) {
            print '|';
            if ( defined $$s{$k} ) {
                print $$s{$k};
            }
        }
        print "\n";
    }
    untie %status;
    unlock_db($h);
}

sub status_log {
    my $h = lock_db(LOCK_SH);

    my %status;
    unless(tie %status, 'GDBM_File', $DB_FILE, O_RDONLY, 0666) {
        error("unable to open database file ${DB_FILE} for reading");
        return;
    }

    while(my ($k,$v)=each(%status)) {
        my $s = thaw($v);
        unless ( defined $$s{'btype'} ) {
            $$s{'btype'} = 'rsync';
        }
        my $msg = dlog('notice','backup status',
                       {'src' => $k},
                       $s);
    }
    untie %status;
    unlock_db($h);
}

sub status_prom {
    my $h = lock_db(LOCK_SH);

    my %status;
    unless(tie %status, 'GDBM_File', $DB_FILE, O_RDONLY, 0666) {
        error("unable to open database file ${DB_FILE} for reading");
        return;
    }
    while(my ($k,$v)=each(%status)) {
        my $s = thaw($v);
        unless ( defined $$s{'btype'} ) {
            $$s{'btype'} = 'rsync';
        }
        foreach my $nk (qw( time exit runtime )) {
            my $fc = '%.2f';
            $fc = '%d' if $nk eq 'exit';
            printf('node_rdbduprunner_backup_status_%s{src="%s",btype="%s"} '."${fc}\n",
                   $nk,
                   $k,
                   $$s{btype},
                   $$s{$nk},
               );
        }
    }
    untie %status;
    unlock_db($h);
}

sub backup_sort {
  my @sortorder=qw( tag host backupdestination );

  unless(defined $$a{priority}) {
    $$a{priority}=(defined $$a{priority} ? $$a{priority} : 0);
  }
  unless(defined $$b{priority}) {
    $$b{priority}=(defined $$b{priority} ? $$b{priority} : 0);
  }
  if($$a{priority} != $$b{priority}) {
    return $$a{priority} <=> $$b{priority};
  }
  foreach my $parm (@sortorder) {
    if($$a{$parm} ne $$b{$parm}) {
      return $$a{$parm} cmp $$b{$parm};
    }
  }
  # somehow, all the paramaters are equal, so just return 0
  return 0;
}

sub lock_file_compose {
  return sprintf('%s/%s.lock',$LOCK_DIR,$_[0]);
}

sub lock_pid_file {
  my $LOCK_FILE=lock_file_compose(@_);
  my $LOCK;
  my $waittime=time();
  my $locked=0;
  my $maxwait = key_selector('maxwait');
  unless(open($LOCK,'+<'.$LOCK_FILE) or open($LOCK,'>'.$LOCK_FILE)) {
    error("unable to open pid file: $LOCK_FILE for writing");
    return 0; # false or fail
  }
  debug("setting alarm for ${maxwait} seconds and locking ${LOCK_FILE}");
  eval {
    local $SIG{ALRM} = sub { die "alarm\n" }; # NB: \n required
    alarm $maxwait;
    if(flock($LOCK,LOCK_EX)) {
      $locked=1;
    }
    alarm 0;
  };
  if ($@) {
    die unless $@ eq "alarm\n";   # propagate unexpected errors
    notice("receieved ALRM waiting to lock ${LOCK_FILE}: alarm: ${maxwait} elapsed time:".(time()-$waittime) );
  }
  else {
    if($locked) {
      debug("lock wait time for $LOCK_FILE: ".(time()-$waittime));
      truncate($LOCK,0); # this shouldn't fail if we have the file opened and locked!
      print $LOCK $$."\n"; # who really cares if this fails?
      return $LOCK; # happiness is a locked file
    }
    else {
      error("failed to lock ${LOCK_FILE} without receiving alarm");
    }
  }
  # this is the fall through for the cases where we have received an alarm
  # or we failed to lock the file without receiving a signal
  close $LOCK;
  return 0;
}

sub unlock_pid_file {
    flock($_[0],LOCK_UN);
    close $_[0];
}


sub tidy {
    my $bh=$_[0];
    my $tag=$$bh{tag};
    my @com;
    if($$bh{btype} eq 'rdiff-backup') {
      @com=($$bh{rdiffbackupbinary},
            verbargs($bh),
            '--force',
            '--remove-older-than',
           );
      if(defined $$bh{maxinc} and not defined $$bh{increments}) {
        list_increments($bh);
      }
      if(defined $$bh{maxinc}) {
        if($$bh{maxinc} =~ /^\d+$/ and
           @{$$bh{increments}} > $$bh{maxinc} ) {
          # too many!
          debug("$tag\t Incs: ".
                scalar @{$$bh{increments}}.
                "\t Max: ".$$bh{maxinc});
          my $lastinc=(sort {$a <=> $b} (@{$$bh{increments}}))[$$bh{maxinc}-1];
          debug("last time to keep for $tag: ".localtime($lastinc));

          my @icom=(@com,$lastinc);

          push(@icom,$$bh{dest});
          info(join(" ",@icom));
          unless($CLI_CONFIG{test}) {
            system(@icom);
            unless($? == 0) {
              error("unable to execute rdiff-backup!");
            }
          }
        }
      }
      if(defined $$bh{maxage} and
         $$bh{maxage} =~ /^\d/) {

        my @icom=(@com,$$bh{maxage});
        push(@icom,$$bh{dest});

        info(join(" ",@icom));
        unless($CLI_CONFIG{test}) {
          system(@icom);
          unless($? == 0) {
            error("unable to execute rdiff-backup!");
          }
        }
      }
    } elsif($$bh{btype} eq 'duplicity') {
      unless(defined $$bh{maxage}) {
        debug("max age is not defined for $$bh{tag}, so we cannot tidy it");
        return;
      }
      my @com=($$bh{duplicitybinary},
               'remove-older-than',
               $$bh{maxage},
               '--force');
      $$bh{useagent} and push(@com,'--use-agent');
      push(@com,verbargs($bh),
           $$bh{dest});

      info(join(" ",@com));
      unless($CLI_CONFIG{test}) {
        set_env($bh);
        system(@com);
        unless($? == 0) {
          error("unable to execute duplicity!");
        }
      }
    }
    else {
      warn("tidy only applies to duplicity and rdiff-backup");
    }
  }

sub set_env {
    my $bh=$_[0];
    my @keys=qw( btype dest path host tag gtag );
    foreach my $key (@keys) {
      if(exists $$bh{$key}) {
        $ENV{"RDBDUPRUNNER_${key}"}=$$bh{$key};
      }
    }
    $ENV{'RDBDUPRUNNER_zfs'} = substr $$bh{'dest'}, 1;
    # grab more stuff from the config and put them into ENV for use by duplicity
    if(defined $$bh{gpgpassphrase}) {
	$ENV{PASSPHRASE}=$$bh{gpgpassphrase};
    }
    if($$bh{dest} =~ /^s3/) {
	if(defined $$bh{awsaccesskeyid}) {
	    $ENV{AWS_ACCESS_KEY_ID}=$$bh{awsaccesskeyid};
	}
	if(defined $$bh{awssecretaccesskey}) {
	    $ENV{AWS_SECRET_ACCESS_KEY}=$$bh{awssecretaccesskey};
	}
    }
}

sub build_increment_list {
  foreach my $bp (BACKUPS()) {
    my $tag=$$bp{tag};
    unless($$bp{btype} eq 'rdiff-backup') {
      next;
    }
	unless(defined $$bp{increments}) {
	    list_increments($bp);
	}
	foreach my $inctime (@{$$bp{increments}}) {
	    # find various tidbits of info about this increment
	    # /home/spin/rdiff-backup/spidermonk-home-spin-wine-wow/rdiff-backup-data/session_statistics.2008-02-22T03:05:48-06:00.data
	    my @d=localtime($inctime);
	    my $rbdate=strftime("%FT%T",@d);
	    my $glob="$$bp{dest}/rdiff-backup-data/session_statistics.$rbdate*.data";
	    my $ssdfile=(glob($glob))[0];
	    my $data={}; # store info from the session stats file... which we never ever ever use!
	    
	    if(defined $ssdfile) {
                my $ssd_handle;
		if(open($ssd_handle, '<', $ssdfile)) {
                    while(my $ln = <$ssd_handle>) {
			$ln =~ /^(\w+)\s+(\d+\.?\d*)/ and $$data{$1}=$2;
		    }
		    close($ssd_handle);
		} else {
		    error("unable to open increment file: $glob $ssdfile");
		}
	    } else {
		notice("unable to find the session statistics file for this increment: $tag $rbdate using glob: $glob");
	    }

	    push(@INCREMENTS,{ inctime => $inctime,
                           incdt => [@d],
                           ssdfile => $ssdfile,
                           ssddata => $data,
                           tag     => $tag,
                           bh      => $bp,
                           backupdestination => $$bp{backupdestination},
                         }
		);
	}
    }
    #print Dumper \@INCREMENTS;
}

sub list_increments {
    my $bp=$_[0];

    my $c="$$bp{rdiffbackupbinary} -l --parsable-output ".$$bp{dest};
    debug($c);
    my @res=`$c`;
    #@res == 1 and next; # if there is only one increment, don't consider it for removal
    foreach my $ln (@res) {
      chomp $ln;
      $ln =~ /^(\d+)\sdirectory$/ or next;
      push(@{$$bp{increments}},$1);
    }
}

sub remove_oldest {
    my $backupdest=$_[0];

    unless(@INCREMENTS > 0) {
	build_increment_list();
    }
    foreach my $ih (sort { $$a{inctime} <=> $$b{inctime} } (@INCREMENTS)) {
	debug("remove_oldest: $$ih{inctime}");
	if(defined $$ih{removed} and $$ih{removed}) {
	    debug("cannot remove previously removed increment for $$ih{tag}");
	    next;
	}
	if(scalar @{$$ih{bh}{increments}} == 1) {
	    # cannot remove the only increment!
	    debug("cannot remove only increment for $$ih{tag}");
	    next;
	}
	unless($backupdest eq 'any' or
	       $backupdest eq $$ih{bh}{backupdestination}) {
	    debug("skipping because it isn't in the backupdestination we are looking for: $backupdest $$ih{bh}{backupdestination}");
	    next;
	}
	my $t=$$ih{inctime};
	my @com=($$ih{bh}{rdiffbackupbinary},
             verbargs($$ih{bh}),
		 '--remove-older-than',($t+1), # do I really need to add 1?
		 $$ih{bh}{dest});
	info(join(" ",@com));
	unless($CLI_CONFIG{test}) {
	    system(@com);
	    unless($? == 0) {
		error("rdiff-backup did not exit cleanly!");
		return 0;
	    }
	}
	$$ih{removed}=1;
#	print Dumper $BACKUPS{$$ih{tag}}{increments};
	shift(@{$$ih{bh}{increments}});
#	print Dumper $BACKUPS{$$ih{tag}}{increments};
	return 1;
    }
}

sub check_space {
    my $bh=$CONFIG{backupdestination}{$_[0]};
    update_bd_space($bh) or return -1;    
    if(defined $$bh{minfree} and $$bh{avail} < $$bh{minfree}) {
	return 0;
    } elsif(defined $$bh{percentused} and $$bh{percent} > $$bh{percentused}) {
	return 0;
    }
    return 1;
}

sub update_bd_space {
    my $bh=$_[0];
    my $com='POSIXLY_CORRECT=1 BLOCKSIZE=512 df -P '.$$bh{path};
    my @a=`$com`;
    unless($? == 0) {
	error("unable to run \"$com\": no further backups will be attempted to this directory");
	$$bh{busted}=1;
        dlog('error','failed to execute df',$bh);
	return 0;
    }
    unless($a[1] =~ /(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\%/) {
	error("unable to parse output from \"$com\": no further backups will be attempted to this directory");
	$$bh{busted}=1;
        dlog('error','failed to parse df',$bh);
	return 0;
    }
    $$bh{size}=$1;
    $$bh{used}=$2;
    $$bh{avail}=$3;
    $$bh{percent}=$4;
    return 1;
}

sub log_exit_status {
  my($bh,$exit)=@_;
  my $msg = dlog('notice','exit status',
                 {'exit' => $exit},
                 $bh);
  $msg =~ s/\"/\\\"/g;
  unless($$bh{local}) {
      my $facility = key_selector('facility');
    my $com="ssh -x -o BatchMode=yes $$bh{host} \"logger -t rdbduprunner -p ${facility}.notice '${msg}'\" < /dev/null";
    #print $com."\n";
    system($com);
  }
}


# given a string, interpret it as 0 or 1 (false or true)
sub bool_parse {
    my $bool = shift;

    if (looks_like_number($bool) and $bool < 0) {
        croak "supposed boolean value appears to be a negative number: ${bool}";
    }
    if ( (looks_like_number($bool) and $bool > 0) or string_any( lc $bool, qw( true t yes on 1 ) ) ) {
        return 1;
    }
    if ( (looks_like_number($bool) and $bool == 0) or string_any( lc $bool, qw( false f no off 0 ) ) ) {
        return 0;
    }
    # this would interpret negative numbers as "false" which is weird and probably wrong
    warn "unable to parse provided value for boolean option (${bool})";
    return;
}

# if the path given is on a zfs filesystem, return the zfs it lives on
sub find_zfs {
  unless ( -d $_[0] ) {
    warn("the path ${_[0]} doesn't exist, so we cannot determine if it is zfs, assuming not");
    return 0;
  }
  my $fstype = `stat -f -c '%T' ${_[0]} | head -1`; chomp $fstype;
  if($fstype eq 'zfs') {
    my $fs = `stat -c '%m' ${_[0]}`;chomp $fs;
    debug("found zfs filesystem at: ${fs}");
    open P, '</proc/mounts' or die "unable to read /proc/mounts";
    foreach(<P>) {
      my @s = split(/\s+/);
      if ( $s[1] eq $fs and $s[2] eq 'zfs' ) {
        debug("found zfs at $s[0]");
        return $s[0];
      }
    }
    close P;
  }
  return 0;
}

# the path must be a directory, and a top level zfs, return said zfs
# pass the path of the backupdestination to this function
sub which_zfs {
  my $backup_destination_path = shift @_;
  unless ( -d $backup_destination_path ) {
    warn("the path ${backup_destination_path} doesn't exist, so we cannot determine if it is zfs, assuming not");
    return 0;
  }
  my $fstype = `stat -f -c '%T' ${backup_destination_path} | head -1`; chomp $fstype;
  unless($fstype eq 'zfs') {
    warn("the path ${backup_destination_path} is not zfs, so we cannot determine which zfs it is");
    return 0;
  }
  my $fs = `stat -c '%m' ${backup_destination_path} | head -1`; chomp $fs;
  unless($fs eq $backup_destination_path) {
    warn("the provided backup destination path is not a top level mount, so we cannot create child zfs (${backup_destination_path},${fs})");
    return 0;
  }
  open P, '</proc/mounts' or die "unable to read /proc/mounts";
  foreach(<P>) {
    my @s = split(/\s+/);
    if ( $s[1] eq $fs and $s[2] eq 'zfs' ) {
      debug("found zfs at $s[0]");
      close P;
      return $s[0];
    }
  }
  close P;
  error("we failed to find the zfs at ${backup_destination_path} in /proc/mounts");
  return 0;
}

# use what is in %CONFIG and global config options to create the
# @BACKUPS array:
sub parse_config_backups {
    local %DEFAULT_CONFIG = %{shift(@_)};
    local %CONFIG = %{shift(@_)};
    local %CLI_CONFIG = %{shift(@_)};

    my @BACKUPS;
    print STDERR Dumper \%DEFAULT_CONFIG if $DEBUG;
    print STDERR Dumper \%CONFIG if $DEBUG;
    print STDERR Dumper \%CLI_CONFIG if $DEBUG;

    # although BackupSet's currently require a name, we don't use that
    # name for anything
    for my $bstag (keys(%{$CONFIG{backupset}})) {
        my @bslist=($CONFIG{backupset}{$bstag});
        if (
            reftype($CONFIG{'backupset'}{$bstag})
            eq reftype([])
        ) {
            @bslist=@{$CONFIG{backupset}{$bstag}};
            # this case can no longer happen because of the config validator
            die("multiple backupsets with the same name: ${bstag}, this cannot happen");
        }
    BS:
        foreach my $bs (@bslist) {
            # the default for localhost key is shortname():
            my $host=(defined $$bs{host}
                      ? $$bs{host}
                      : key_selector('localhost'));
            my $btype;
            my $backupdest;

            if (defined $CLI_CONFIG{filterhost} and $host !~ /$CLI_CONFIG{filterhost}/) {
                debug("skipping backup on ${host} due to filter");
                next BS;
            }
            dlog('debug','backupset',$bs);

            if (defined $$bs{backupdestination}) {
                $backupdest=$$bs{backupdestination};
            } elsif (defined $CONFIG{defaultbackupdestination}) {
                $backupdest=$CONFIG{defaultbackupdestination};
            }
            else {
                error("there is no BackupDestination defined for the BackupSet ($bstag): so it cannot be processed");
                next BS;
            }
            if (defined $CLI_CONFIG{filterdest} and $backupdest !~ /$CLI_CONFIG{filterdest}/) {
                debug("skipping backup on ${backupdest} due to filter");
                next BS;
            }
            unless (defined $CONFIG{backupdestination}{$backupdest}) {
                error("there is no such backupdestination as ${backupdest} in the config, skipping");
                next BS;
            }
            my $backupdestpath=$CONFIG{backupdestination}{$backupdest}{path};

            # this should already by validated by the config
            if (defined $CONFIG{backupdestination}{$backupdest}{type} ) {
                # check to make sure that if the type isn't set, we set it to rsync
                $btype=$CONFIG{backupdestination}{$backupdest}{type};
            } else {
                $btype='rsync';
            }
            if ($btype eq 'duplicity' and defined $$bs{host}) {
                error("${bstag} is a duplicity backup with host set to $$bs{host}: duplicity backups must have a local source!");
                next BS;
            }

            # paths can be a singleton or array, because that's how
            # Config::General works:
            my @paths
                = defined $$bs{path}
                ? (ref($$bs{path}) eq "ARRAY"
                   ? @{$$bs{path}}
                   : ($$bs{path}))
                : ();
            # if we are going to inventory then do so:
            if (dtruefalse($bs,'inventory') and not dtruefalse($bs,'disabled')) {
                push(@paths,inventory_host($backupdest,$bs));
            }
            # process each path into a "backup" data structure:
        PATH:
            foreach my $path (@paths) {
                # remove any trailing slash, but only if there is
                # something before it!:
                $path =~ s/.+\/$//;
                if (defined $CLI_CONFIG{filterpath} and $path !~ /$CLI_CONFIG{filterpath}/) {
                    debug("skipping backup on ${backupdest} due to filter");
                    next PATH;
                }

                # very important to make a copy here:
                print STDERR Dumper $bs if $DEBUG;
                my $bh = merge(
                    {
                        path => $path,
                        host => $host,
                        local => defined $$bs{host} ? 0 : 1,
                        backupdestination => $backupdest,
                        btype => $btype,
                    },
                    $bs);
                print STDERR Dumper $bh if $DEBUG;
                # we don't use catfile here because it mangles urls:
                if (defined $$bh{tag}) {
                    $$bh{dest} = join('/',$backupdestpath,$$bh{tag});
                    $$bh{gtag}='generic-'.$$bh{tag};
                } else {
                    my $tag = path_munge_tag($$bh{path});
                    $bh = merge(
                        {
                            tag => $host.$tag,
                            gtag => 'generic'.$tag,
                            dest => join('/',$backupdestpath,$host.$tag),
                        },
                        $bh);
                }
                print STDERR Dumper $bh if $DEBUG;

                if ($$bh{btype} eq 'rsync') {
                    $$bh{path}=$$bh{path}.'/';
                    $$bh{path} =~ s/\/\/$/\//; # remove double slashes
                }

                @{$$bh{excludes}} = exclude_list_generate($bh);
                $$bh{exclude}=[];
                foreach my $exc (ref($$bs{exclude}) eq "ARRAY" ? @{$$bs{exclude}} : ($$bs{exclude})) {
                    if (defined $exc and length $exc > 0) {
                        push(@{$$bh{exclude}},$exc);
                    }
                }
                print STDERR Data::Dumper->Dump([$bh], [qw(bh)]) if $DEBUG;
            KEY:
                for my $key (sort(
                    hashref_key_filter_array('type',
                                             qr{^(list|table)},
                                             $config_definition{'default'}{fields},
                                             $config_definition{'backupset'}{fields},
                                             $config_definition{'backupdestination'}{fields},
                                             $config_definition{'cli'}{fields}),
                    keys(%DEFAULT_CONFIG))) {
                    # for my $key (qw( stats wholefile inplace checksum verbose progress verbosity terminalverbosity )) {
                    # this is a list of items that exist at only one layer and shouldn't be smashed many of them are command line options:
                    next KEY if string_any($key, qw(filterpath filterdest filterhost defaultbackupdestination type maxprocs level facility force full maxwait skipfstype localhost test excludepath));
                    my $v = key_selector($key,$bh);
                    $$bh{$key} = $v if defined $v;
                }
                print STDERR Data::Dumper->Dump([$bh], [qw(bh)]) if $DEBUG;
                my @split_host = split(/\./,$$bh{host});
                $$bh{'src'} = $$bh{path};
                unless($$bh{local}) {
                    $$bh{'src'} = join($$bh{btype} eq 'rsync' ? ':' : '::',
                                       $$bh{host},
                                       $$bh{path});
                }
                dlog('debug','backup',$bh);
                push(@BACKUPS,$bh);
            }
        }
    }
    print STDERR Dumper [sort { $$a{dest} cmp $$b{dest} } @BACKUPS] if $DEBUG;
    return @BACKUPS;
}
# end of parse_config_backups

sub inventory_host {
    my $backupdest = shift;
    my $bs = shift;
    my @paths;

    my %filters;
    for my $k (qw(skipfstype allowfs skip skipre)) {
        $filters{$k} = [hashref_key_array_combine($k,
                                                  hashref_key_hash(\%DEFAULT_CONFIG,'default'), # defaults
                                                  \%CONFIG, # config file, top level
                                                  $CONFIG{backupdestination}{$backupdest}, # from the destination
                                                  $bs, # ourselves
                                                  \%CLI_CONFIG)];
    }
    print STDERR Dumper \%filters if $DEBUG;
    # perform inventory
    debug("performing inventory on ".(defined $$bs{host} ? $$bs{host} : 'localhost'));
    my $inventory_command='cat /proc/mounts';
    if (defined $$bs{host}) {
        $inventory_command="ssh -x -o BatchMode=yes $$bs{host} ${inventory_command} < /dev/null";
    }
    if (-x '/usr/bin/waitmax') {
        $inventory_command="/usr/bin/waitmax 30 ${inventory_command}";
    } elsif ( -x '/bin/waitmax') {
        $inventory_command="/bin/waitmax 30 ${inventory_command}";
    }
    my @a=`${inventory_command}`;
    print STDERR Dumper \@a if $DEBUG;
    if ($? == 0) {
        my @seen;
    M:
        foreach my $m (sort(@a)) {
            my @e=split(/\s+/,$m);
            if ( defined $filters{allowfs}
                 and scalar @{$filters{allowfs}} > 0 ) {
                if ( not string_any($e[2], @{$filters{allowfs}}) ) {
                    debug("filesystem at $e[1] is not allowed via the allow list: ${e[2]}");
                    next M;
                }
            } elsif ( defined $filters{skipfstype} and string_any($e[2], @{$filters{skipfstype}}) ) {
                debug("filesystem at $e[1] is not allowed via the skip list: ${e[2]}");
                next M;
            }
            if (defined $filters{skip}) {
                next M if string_any($e[1], (ref($filters{skip}) eq "ARRAY" ? @{$filters{skip}} : ($filters{skip})));
            }
            if (defined $filters{skipre}) {
                foreach my $skipre (ref($filters{skipre}) eq "ARRAY" ? @{$filters{skipre}} : ($filters{skipre})) {
                    if ($e[1] =~ /$skipre/) {
                        next M;
                    }
                }
            }
            # skip seen devices
            grep(/^$e[0]$/,@seen) and next;
            push(@seen,$e[0]);
            push(@paths,$e[1]);
        }
    } else {
        error("unable to inventory $$bs{host}");
    }
    return @paths;
}


sub key_select {
    print STDERR Dumper \@_ if $DEBUG;
    my $key = shift;
    for my $h (reverse(@_)) {
        if(defined $$h{$key}) {
            return $$h{$key};
        }
    }
    return;
}

# parse all the args using specified options, return hash config?
sub parse_argv {
    my $argv = shift;
    my @options_array = @_;
    my $cli_config = {};

    print STDERR Dumper $argv,\@options_array if $DEBUG;
    GetOptionsFromArray($argv, $cli_config, @options_array);
    print STDERR Dumper $argv if $DEBUG;
    print STDERR Dumper $cli_config if $DEBUG;
    return $cli_config;
}

# copied from the old version of List::Util:
sub string_any {
    my $s = shift;
    foreach (@_) {
        return 1 if $s eq $_;
    }
    return 0;
}

sub make_dirs {
    # we can create our own directories if needed:
    for my $dir ( $STATE_DIR, $CONFIG_DIR, $LOCK_DIR, $LOG_DIR ) {
        unless ( -d $dir ) {
            my @created;
            unless ( @created = make_path( $dir, { mode => 0700 } ) ) {
                die "unable to create directory: ${dir}";
            }
            unless ( string_any( $dir, @created ) ) {
                warn @created;
                die
                    "make_path did not return the expected result trying to create ${dir}";
            }
        }
    }
}

sub find_configs {
    my $dirs = shift;
    my $stems = shift;
    print STDERR Data::Dumper->Dump([$dirs,$stems],['find_configs_params']) if $DEBUG;
    my @files;

    if ( scalar @{$stems} > 0 ) {
        for my $stem (@{$stems}) {
            for my $e (@extensions) {
                my $f = join('.', $stem, $e);
                push(@files, $f) if -f $f;
            }
        }
    }
    if ( scalar @{$dirs} > 0 ) {
        foreach my $dir (@{$dirs}) {
            #print STDERR Dumper [map { catfile($dir,join('.','*',$_))} (@extensions) ];
            push @files, map { glob($_[0]) } (map { catfile($dir,join('.','*',$_)) } (@extensions) );
        }
    }
    #print STDERR Dumper \@files;
    return @files;
}

sub load_config_conf {
    my $file = shift;
    die "file ${file} does not exist, cannot be loaded" unless -f $file;
    my $conf =
        new Config::General(-ConfigFile     => $file,
                            -IncludeGlob    => 1,
                            -AutoTrue       => 1,
                            -LowerCaseNames => 1);
    return {$conf->getall()};
}

sub load_config_yaml {
    return YAML::Syck::LoadFile($_[0]);
}

sub load_config_json {
    my $h;
    open($h,"<",$_[0]) or croak "unable to open ${_[0]} for reading";
    return decode_json(<$h>);
}

sub load_configs {
    # array of files is the only parameters
    print STDERR Data::Dumper->Dump(\@_,['load_configs_params']) if $DEBUG;
    my $configs = {};

    my $pat = join('|',@extensions);
    for my $file (@_) {
        if(my ($ext) = $file =~ m{ [.] ($pat) $}xms) {
            $$configs{$file} = $config_load_dispatch{$ext}->($file);
        }
        else {
            croak "no pattern matched for config file: ${file}";
        }
    }
    if (scalar keys %{$configs} == 0) {
        croak("no configuration files were found in any configured locations!");
    }
    print STDERR Data::Dumper->Dump([$configs],['load_configs']) if $DEBUG;
    return $configs;
}

sub hash_array_merge {
    my $h = shift;
    foreach my $fh (@_) {
        $h = merge($h,$fh);
    }
    return $h;
}

sub validate_each {
    print STDERR Data::Dumper->Dump([\@_],['validate_each']) if $DEBUG;
    state $config_validator = Config::Validator->new(%config_definition);
  CONFIG:
    while(my ($file,$config) = each(%{$_[0]})) {
        eval { $config_validator->validate($config, 'global'); 1; }
            or do {
                my $error = $@;
                warn $error;
                #print STDERR Dumper [$file,$config];
                die "config file failed validation: ${file}";
            };
    }
    return 1;
}


sub merge_configs {
    print STDERR Data::Dumper->Dump([\@_],['merge_configs']) if $DEBUG;
    my $h;
    my $merger = Hash::Merge->new('RETAINMENT_PRECEDENT');
  CONFIG:
    foreach my $config (values(%{$_[0]})) {
        unless ($h) {
            $h = clone($config);
            next CONFIG;
        }
        print STDERR Data::Dumper->Dump([$h,$config],['merge_configs_left','merge_configs_right']) if $DEBUG;
        $h = $merger->merge($h,$config);
        print STDERR Data::Dumper->Dump([$h],['merge_configs_merged']) if $DEBUG;
    }
    print STDERR Data::Dumper->Dump([$h],['merge_configs_h']) if $DEBUG;
    return $h;
}

sub merge_config_definition {
    for my $section (qw(cli global backupdestination backupset)) {
        $config_definition{$section}{fields} = merge(
            $config_definition{$section}{fields},
            hashref_keys_drop(
                hashref_key_array_match(\%DEFAULT_CONFIG,
                                        'sections',
                                        $section),
                'default',
                'getopt',
                'sections',
                'mode',)
        );
    }
}

sub rdbduprunner {

    make_dirs();
    merge_config_definition();
    print STDERR Dumper \%config_definition if $DEBUG;

    my $config_validator = Config::Validator->new(%config_definition);

    my @options = hashref_key_array(\%DEFAULT_CONFIG,
                                    'getopt');
    print STDERR Dumper \@options if $DEBUG;

    %CLI_CONFIG = %{parse_argv(\@ARGV, @options)};
    $CLI_CONFIG{test} = 1 unless defined $CLI_CONFIG{test};
    $config_validator->validate(\%CLI_CONFIG,'cli');

    # major mode command line options are denoted by having a mode
    # key, and those options are mutually exclusive:
    Config::Validator::mutex(\%CLI_CONFIG,
                             keys(%{hashref_key_hash(\%DEFAULT_CONFIG,
                                                     'mode')}
                                )
                              );
    if ( scalar @ARGV ) {
        print STDERR Dumper \@ARGV;
        die "unparsed options on the command line: ".join(' ',@ARGV);
    }

    # print the SYNOPSIS section and exit
    pod2usage(-1) if $CLI_CONFIG{help};

    create_dispatcher( $APP_NAME,
                       key_selector('facility'),
                       key_selector('level'),
                       $LOG_FILE );
    $RUNTIME=time();
    dlog('info','starting',{});

    my @config_files;
    if ( defined $CLI_CONFIG{config} or defined $CLI_CONFIG{confd} ) {
        push(@config_files, $CLI_CONFIG{config}) if defined $CLI_CONFIG{config};
        push(@config_files, find_configs([$CLI_CONFIG{confd}],[])) if defined $CLI_CONFIG{confd};
    }
    elsif( ($USER eq 'root' and -f "/etc/rdbduprunner.rc") or -f catfile($HOME,'.rdbduprunner.rc') ) {
        my $legacy_config = ($USER eq 'root' and -f "/etc/rdbduprunner.rc") ? "/etc/rdbduprunner.rc" : catfile($HOME,'.rdbduprunner.rc');
        _warning("found legacy config file at ${legacy_config}");
        push(@config_files, $legacy_config);
    }
    else {
        push(@config_files,
             find_configs(
                 [catfile($CONFIG_DIR,'conf.d')], # one directory
                 [catfile($CONFIG_DIR,'rdbduprunner')], # one stem
             )
         );
    }
    my $configs = load_configs(@config_files);
    validate_each($configs);
    %CONFIG = %{merge_configs($configs)};

    #%CONFIG = load_all_configs();
    dlog('debug','config',\%CONFIG);
    eval { $config_validator->validate(\%CONFIG,'global'); 1; }
        or do {
            my $error = $@;
            warn $@;
            die "combined configuration files failed validation, probably due to duplicated keywords!";
        };

    # recreate the dispatcher with values from loading the config
    # files:
    create_dispatcher( $APP_NAME,
                       key_selector('facility'),
                       key_selector('level'),
                       $LOG_FILE );

    my $mode='backup';
 MODE:
    for my $m (keys(%{hashref_key_hash(\%DEFAULT_CONFIG,
                                       'mode')})) {
        if(exists $CLI_CONFIG{$m} and $CLI_CONFIG{$m}) {
            $mode = $m;
            last MODE;
        }
    }
    if ($mode eq 'backup') {
        backup_mode();
    }
    else {
        print STDERR Dumper [$mode, $DEFAULT_CONFIG{$mode} ] if $DEBUG;
        $DEFAULT_CONFIG{$mode}{mode}->();
    }

    dlog('info',
         'exiting',
         {'total_run_time_seconds' => time()-$RUNTIME});
}

sub dump_mode {
    print Dumper \%CONFIG;
    #@BACKUPS = parse_config_backups(\%DEFAULT_CONFIG, \%CONFIG, \%CLI_CONFIG);
    print Dumper [BACKUPS()];
    notice("you asked me to dump and exit!");
}

sub status_mode {
  foreach my $bh (sort backup_sort (BACKUPS())) {
    my @com;
    if($$bh{btype} eq 'duplicity') {
      @com=($$bh{duplicitybinary},'collection-status');
      $$bh{useagent} and push(@com,'--use-agent');
    } elsif($$bh{btype} eq 'rdiff-backup') {
      @com=($$bh{rdiffbackupbinary},'--list-increment-sizes');
    } elsif($$bh{btype} eq 'rsync') {
      @com=('du','-cshx');
    }
    unless($$bh{btype} eq 'rsync') {
      push(@com,verbargs($bh));

    }
    push(@com,$$bh{dest});
    info(join(" ",@com));
    unless($CLI_CONFIG{test}) {
      my $lock=lock_pid_file($$bh{host});
      set_env($bh);
      system(@com);
      unless($? == 0) {
        error('unable to execute '.$com[0].'!');
      }
      unlock_pid_file($lock);
    }
  }
}

sub listoldest_mode {
    build_increment_list();
    foreach my $ih (sort { $$a{inctime} <=> $$b{inctime} } (@INCREMENTS)) {
        print localtime($$ih{inctime}).' '.$$ih{bh}{dest}.' '.$$ih{tag}."\n";
    }
}

sub remove_mode {
    build_increment_list();
    remove_oldest('any');
}

sub orphans_mode {
  foreach my $bh (sort backup_sort (BACKUPS())) {
    if($$bh{btype} eq 'rdiff-backup') {
      my @com=('find',$$bh{dest},'-type','f','-name','rdiff-backup.tmp.*');
      info(join(" ",@com));
      system(@com);
    }
  }
}

sub cleanup_mode {
    foreach my $bh (sort backup_sort (BACKUPS())) {
        my @com;
        if($$bh{btype} eq 'duplicity') {
            push(@com,$$bh{duplicitybinary},'cleanup');
            $$bh{useagent} and push(@com,'--use-agent');
            push(@com,'--force') if dtruefalse(\%CLI_CONFIG, 'force');
        } elsif($$bh{btype} eq 'rdiff-backup') {
            push(@com,$$bh{rdiffbackupbinary},'--check-destination-dir');
        }
        else {
          warn("cleanup function only implmented for duplicity and rdiff-backup");
          next;
        }
        if ( defined $$bh{tempdir} ) {
            if ( -d $$bh{tempdir} ) {
                push( @com, '--tempdir', $$bh{tempdir} );
            }
            else {
                warn("specified temporary directory does not exist, not using it: $$bh{tempdir}");
            }
        }
        push(@com,verbargs($bh),
             $$bh{dest});
        info(join(" ",@com));
        unless($CLI_CONFIG{test}) {
            my $lock=lock_pid_file($$bh{host});
            set_env($bh);
            system(@com);
            unless($? == 0) {
                error("unable to execute $$bh{btype}!");
            }
            unlock_pid_file($lock);
        }
    }
}

sub tidy_mode {
    foreach my $bh (sort backup_sort (BACKUPS())) {
      my $lock;
      unless($CLI_CONFIG{test}) {
	$lock=lock_pid_file($$bh{host});
      }
        tidy($bh);
      unless($CLI_CONFIG{test}) {
	unlock_pid_file($lock);
      }
    }
}

sub average_mode {
    my $avcom;
 BACKUP:
    foreach my $bh (sort backup_sort (BACKUPS())) {
        print STDERR Dumper $bh if $DEBUG;
        $avcom="$$bh{rdiffbackupbinary} --calculate-average";
        unless($$bh{btype} eq 'rdiff-backup') {
          warn("average function only applies to rdiff-backup type backups");
            next BACKUP;
        }
        $avcom.=" $$bh{dest}/rdiff-backup-data/session_statistics.*.data";
        debug("trying to calculate the average: ${avcom}");
        system($avcom);
    }
}

sub compare_mode {
  foreach my $bh (sort backup_sort (BACKUPS())) {
    my @com;
    if ($$bh{btype} eq 'duplicity') {
      @com=($$bh{duplicitybinary},'verify');
      $$bh{useagent} and push(@com,'--use-agent');
    }
    elsif($$bh{btype} eq 'rdiff-backup') {
      @com=($$bh{rdiffbackupbinary},'--compare','--no-eas');
    }
    else {
      warn("verify function not implemented for rsync backups");
      next;
    }
    push(@com,verbargs($bh),'--exclude-other-filesystems');
    foreach my $f (@{$$bh{excludes}}) {
      push(@com,'--exclude-globbing-filelist',
	   $f);
    }
    if ($$bh{btype} eq 'duplicity') {
      push(@com,$$bh{dest},$$bh{path});
    } else {
      unless(bool_parse($$bh{sshcompress})) {
	push(@com,'--ssh-no-compression');
      }
      push(@com,'--exclude-device-files',$$bh{src},$$bh{dest});
    }
	
    info(join(" ",@com));
    unless($CLI_CONFIG{test}) {
      my $lock=lock_pid_file($$bh{host});
      set_env($bh);
      system(@com);
      my $mainret=$?;
      unless($mainret == 0) {
	error("$$bh{btype} exited with an error");
      }
      unlock_pid_file($lock);
    }
  }
}
sub list_mode {
  foreach my $bh (sort backup_sort (BACKUPS())) {
    my @com;
    unless($$bh{btype} eq 'duplicity') {
      warn("list function only applies to duplicity type backups");
      next;
    }
    @com=($$bh{duplicitybinary},'list-current-files');
    $$bh{useagent} and push(@com,'--use-agent');
    push(@com,verbargs($bh));
    push(@com,$$bh{dest});
    info(join(" ",@com));
    unless($CLI_CONFIG{test}) {
      my $lock=lock_pid_file($$bh{host});
      set_env($bh);
      system(@com);
      unless($? == 0) {
        error('unable to execute '.$com[0].'!');
      }
      unlock_pid_file($lock);
    }
  }
}

sub backup_mode {
  # here we will eventually just perform the backups
  # first we check for space on rdiff-backup destinations and free some up,
  # before forking away in perform_backups
  my @b=BACKUPS();
 BACKUP:
  foreach my $bh (@b) {
    if($$bh{btype} eq 'rdiff-backup') {
      if($$bh{dest} =~ /\:\:/) {
        info("we are assuming the destination $$bh{dest} is remote and will not attempt to manage it's disk space");
      } else {
        while(1) {
          my $ans=check_space($$bh{backupdestination});
          if($ans == -1) {
            error("unable to determine if this backupdestination ($$bh{backupdestination}) has enough free space");
            error("no backups to this backupdestination will be attempted and this message will be repeated only once");
            $CONFIG{backupdestination}{$$bh{backupdestination}}{busted}=1;
            next BACKUP;
          } elsif($ans == 0) {
            unless(remove_oldest($$bh{backupdestination})) {
              # we failed to remove an increment from the backupdestination
              # we cannot do backups on this bd for this run!
              _warning("unable to remove an increment on backupdestination ($$bh{backupdestination}:$CONFIG{backupdestination}{$$bh{backupdestination}}{path})");
              _warning("no further attempts will be made to do backups to this destination");
              $CONFIG{backupdestination}{$$bh{backupdestination}}{busted}=1;
              next BACKUP;
            }
            # we can just fall out now and let check_space() run again to see if it helped
          } elsif($ans == 1) {
            # we have enough space to proceed
            last;
          }
        }
      }
    }
  }
  perform_backups(@b);
}


sub hashref_key_array {
    my $m = shift;
    my $key = shift;
    my @a;
    for my $h (values(%{$m})) {
        push(@a, $$h{$key}) if exists $$h{$key};
    }
    print STDERR Data::Dumper->Dump([\@a], [qw(hashref_key_array)]) if $DEBUG;
    return @a;
}

sub hashref_key_hash {
    my $m = shift;
    my $key = shift;
    my $a = {};
    while(my ($k,$v) = each(%{$m})) {
        $$a{$k} = $$v{$key} if exists $$v{$key};
    }
    #print STDERR Data::Dumper->Dump([$a], [qw(hashref_key_hash)]) if $DEBUG;
    return $a;
}

sub hashref_keys_drop {
    my $m = clone(shift);
    while(my ($k,$v) = each(%{$m})) {
        for my $key (keys(%$v)) {
            delete $$v{$key} if string_any($key,@_);
        }
    }
    print STDERR Data::Dumper->Dump([$m], [qw(hashref_keys_drop)]) if $DEBUG;
    return $m;
}

sub hashref_key_filter_array {
    my $key = shift;
    my $q = shift;
    my %a;
    foreach my $m (@_) {
        while(my ($k,$v) = each(%{$m})) {
            if ($$v{$key} !~ $q) {
                $a{$k}=1;
            }
        }
    }
    print STDERR Data::Dumper->Dump([\%a],[qw(hashref_key_filter_array)]) if $DEBUG;
    return keys(%a);
}

# we should not assume that the key is an array, it might be a scalar
sub hashref_key_array_combine {
    my $key = shift;
    my %a;
    foreach my $m (@_) {
        if (defined $$m{$key} ) {
            if ( ref $$m{$key} and reftype $$m{$key} eq reftype []) {
                for my $e (@{$$m{$key}}) {
                    $a{$e} =1;
                }
            }
            else {
                $a{$$m{$key}} = 1; # assume it's a scalar;
            }
        }
    }
    print STDERR Data::Dumper->Dump([\%a],[qw(hashref_key_filter_combine)]) if $DEBUG;
    return keys(%a);
}

# return cloned hash of hashes consiting of keys where given hash
# values contain an arrayref which contains value
sub hashref_key_array_match {
    my $h = clone(shift);
    my $key = shift;
    my $value = shift;
    for my $k (keys(%{$h})) {
        delete $$h{$k} unless string_any($value,@{$$h{$k}{$key}});
    }
    return $h;
}

sub dtruefalse {
    my $h = shift;
    croak "dtrue needs a hashref" unless reftype $h eq reftype {};
    my $k = shift;
    if ( defined $$h{$k} ) {
        return bool_parse( $$h{$k} );
    }
    return;
}

sub shortname {
    my $h = hostname();
    my @split_host = split(/\./, $h);
    return $split_host[0];
}

sub key_selector {
    my $key = shift;
    my $bh = shift;
    my @hashes = (hashref_key_hash(\%DEFAULT_CONFIG,'default'));

    return undef unless exists $DEFAULT_CONFIG{$key};
    if ( exists $DEFAULT_CONFIG{$key} and string_any('global', @{$DEFAULT_CONFIG{$key}{sections}}) ) {
        push(@hashes, \%CONFIG);
    }
    if ( $bh
         and exists $DEFAULT_CONFIG{$key}
         and string_any('backupdestination', @{$DEFAULT_CONFIG{$key}{sections}})
         and exists $CONFIG{backupdestination}{$$bh{backupdestination}} ) {
        push(@hashes, $CONFIG{backupdestination}{$$bh{backupdestination}});
    }
    if ( $bh
         and exists $DEFAULT_CONFIG{$key}
         and string_any('backupset', @{$DEFAULT_CONFIG{$key}{sections}})) {
        push(@hashes, $bh);
    }
    if ( string_any('cli', @{$DEFAULT_CONFIG{$key}{sections}}) ) {
        push(@hashes, \%CLI_CONFIG);
    }
    # print STDERR Data::Dumper->Dump([\@hashes],
    #                                 [qw(key_selector)]) if $DEBUG;
    return key_select($key, @hashes);
}

sub BACKUPS {
    unless ( scalar @BACKUPS > 0 ) {
        @BACKUPS = parse_config_backups(\%DEFAULT_CONFIG, \%CONFIG, \%CLI_CONFIG);
    }
    return @BACKUPS;
}

sub exclude_list_generate {
    my $bh = shift;
    my @e;
    my $exclude_path = key_selector('excludepath');

    my $epath=catfile($exclude_path,
                      $$bh{btype} eq 'rsync'
                      ? 'excludes'
                      : 'rdb-excludes');

    if ( -f catfile($epath,'generic') ) {
        push(@e, catfile($epath,'generic'));
    }
    if ( -f catfile($epath, $$bh{gtag}) ) {
        push(@e, catfile($epath, $$bh{gtag}));
    }
    if ( -f catfile($epath, $$bh{tag}) ) {
        push(@e, catfile($epath, $$bh{tag}));
    }
    return @e;
}

# turn the path into a tag
sub path_munge_tag {
    my $path = shift;
    $path =~ s/\//\-/g;
    $path =~ s/ /_/g;
    $path eq '-' and $path='-root';
    return $path;
}

# return the exit status if exited normally, or the negative of the
# signal if signalled
sub exit_status {
    POSIX::WIFEXITED($_[0]) and return int(POSIX::WEXITSTATUS($_[0]));
    POSIX::WIFSIGNALED($_[0]) and return int(POSIX::WTERMSIG($$_[0])) * -1;
    return int(-1);
}

# Preloaded methods go here.

# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Backup::rdbduprunner - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Backup::rdbduprunner;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Backup::rdbduprunner, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

Aran Cox, E<lt>arancox@gmail.com<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2022 by Aran Cox

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.34.1 or,
at your option, any later version of Perl 5 you may have available.


=cut
