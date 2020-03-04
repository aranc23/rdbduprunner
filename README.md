# NAME

rdbduprunner - perl magic wrapper for rsync, rdiff-backup, and duplicity

# SYNOPSIS

**rdbduprunner** {**-h|--help**}

**rdbduprunner** {**--calculate-average**|**--check**|**--cleanup**|**--compare**|**--verify**|**--dump**|**--list**|**--list-oldest**|**--orphans**|**--remove-oldest**|**--status**|**--tidy**} {**--test**|**--notest**} {**--config** _path_} {**--dest** _regex_} {**--host** _regex_} {**--path** _regex_} {**--facility** _user|daemon|..._} {**--level** _info|warn|..._} {**--lockfile** _path_} {**--logfile** _path_} {**-t|--terminal-verbosity** _integer_} {**--verbosity** _integer_} {**-v|--verbose**} {**--progress**} {**--maxinc** _integer_} {**--maxage** _timespec_} {**--stats**|**--nostats**} {**--tempdir** _path_} {**--full**} {**--force**} {**--maxprocs** _integer_} {**--maxwait** _integer_}

# DESCRIPTION

rdbduprunner is a wrapper for rsync, rdiff-backup, and duplicity
backups.  By default rdbduprunner will get all it's configuration from
~/.rdbduprunner.rc using an apache-esque config file format parsed by
the Config::General module.

General usage involves running rdbduprunner with no options which will
only print out warnings and the commands that would be invoked if you
were to run it with the --notest option. Then run it again with the
\--notest option to see the output.

Other common options involve filtering which backups to run, adjusting
the verbosity of the output, adjusting logging, and so on.

# OPTIONS

## MAJOR MODES

rdbduprunner's primary mode is "backup" and the following override
that; only one of the following is allowed for any invocation of
rdbduprunner.  Many only apply to one or both of rdiff-backup or
duplicity since they act on archives of their own creation.  For rsync
backups tools like ls and du perform similar functions.

- {**--calculate-average**} (rdiff-backup only)

    Parses run files from rdiff-backup to calculate average increment
    size.  If you do not limit which backups this option applies to using
    \--dest, --host, or --path options you will get the average increment
    size of all backups that rdbduprunner is configured to run with
    rdiff-backup.

- {**--check**|**--cleanup**} (rdiff-backup/duplicity only)

    Both options are identical.  duplicty backups will have the cleanup
    option run on the destination directory.  For rdiff-backup the
    \--check-destination-dir option will be run against the directory.

- {**--compare**|**--verify**} (rdiff-backup/duplicity only)

    Passes the compare option to duplicty and the --verify option to
    rdiff-backup which both have the purpose of printing what has changed
    since the last backup, in other words what would be backed up on the
    next run.

- {**--dump**}

    Simply dumps the internal data structures for backups and
    configuration options and exits.  Meant purely for debugging.

- {**--list**} (duplicity only)

    Passes the list-current-files option to duplicity, since duplicity
    stores everything inside a tar file.

- {**--list-oldest**} (rdiff-backup only)

    Lists all increments from all rdiff-backup type backups in the order
    of their age.

- {**--orphans**} (rdiff-backup only)

    Find orphaned rdiff-backup temporary files inside backup destinations
    and print those file names to stdout (for deletion, likely.)

- {**--remove-oldest**} (rdiff-backup only)

    Removes the oldest known backup from all known rdiff-backup type
    backups.  Should remove only one backup regardless of other settings.
    Meant primarily for testing?  Ignores all other settings for cleaning
    up rdiff-backup style backups. This option honors the --test/--notest
    flags and will only print how rdiff-backup would be run if --notest
    isn't specified as well.

- {**--status**}

    Works on all backup types.  On rsync invokes du, on duplicity uses the
    collection-status option and on rdiff-backup uses the
    \--list-increment-sizes option.  This option requires --notest to
    execute, primarily because of the time it takes to run the operations.

- {**--tidy**} (rdiff-backup/duplicity only)

    Attempts to apply the settings for a backup regarding the maximum
    number of increments or maximum age of an increment to all or
    specified backups.

## SUB OPTIONS

- {**--test**|**--notest**}

    The default invocation assumes --test which causes rdbduprunner to
    print which commands it would run.  Passing --notest will cause
    rdbduprunner to actually run the backup commands.

- {**--dest** _regex_}

    This option causes the backups to be run to be filtered based on the
    BackupDestination.

- {**--host** _regex_}

    This option causes the backups to be run to be filtered based on the
    Host.

- {**--path** _regex_}

    This option causes the backups to be run to be filtered based on the
    path on the host to be backed up.

- {**-t|--terminal-verbosity** _integer_}

    Increases logging verbosity to the terminal with rdiff-backup or
    duplicity backups.

- {**--verbosity** _integer_}

    Increases logging verbosity to the rdiff-backup/duplicity log files.

- {**-v|--verbose**} (rsync only)

    Passes -v to rsync invocations.

- {**--progress**} (rsync only)

    Passes --progress to rsync invocations.

- {**--facility** _user|daemon|..._}

    Default: user
    Changes the facility as passed to the syslog subsystem.

- {**--level** _debug|info|notice|warning|error|critical|alert|emergency_}

    Default: info
    Syslog severity level which is passed to the logging dispatcher. Log
    messages of the specified severity or greater will be logged to
    syslog, stdout, and the rdbduprunner log file.

- {**--maxinc** _integer_}

    Acts as if the MaxInc config option were applied to every backup in
    the configuration, but the backup specific MaxInc still takes
    precendence for any given backup.

- {**--maxage** _timespec_}

    Acts as if the MaxAge config option were applied to every backup in
    the configuration, but the backup specific MaxAge still takes
    precendence for any given backup.

- {**--stats**|**--nostats**}

    The default is to pass the various --stats options to the underlying
    binaries when making backups, but passing --nostats will suppress
    this.

- {**--tempdir** _path_}

    Pass the --tempdir or --temp-dir options to underlying binaries in the
    same manner as if the TempDir global config option had been specified.

- {**--full**} (duplicity only)

    Passess the full option to duplicity backup.

- {**--force**} (duplicity only)

    Passess the --force option to duplicity cleanup mode.

- {**--config** _path_}

    Change path to configuration file.

- {**--maxprocs** _integer_}

    Default: 1
    Maximum number of simultaneous backups to perform.  rdbduprunner will
    never do more than one backup from any given host at a time but if
    there are multiple hosts multiple backups should occur at once.
    See MaxProcs global config option.

- {**--maxwait** _integer_}

    Default: 86400
    Maximum number of seconds to wait for a lock on any given per-host
    lock file.
    See MaxWait global config option.

- {**--allow-source-mismatch**} (duplicity only)

    Passes the identical option to duplicity.  No affect on other backup
    types.

# RETURN VALUE

# ERRORS

# DIAGNOSTICS

# EXAMPLES

# ENVIRONMENT

# FILES

## `$HOME/.rdbduprunner.rc`

rdbduprunner's config file is an Apache style config file parsed by
the Config::General perl module. It consists of global options,
options enclosed in a BackupDestination config section and options
enclosed in a BackupSet section.  The options names are case
insensitive. Options are generally honored in this order:

- Command line options
- BackupSet options
- BackupDestination options
- Global options

### Global Options

- _DuplicityBinary_ - path to duplicity
- _RdiffBackupBinary_ - path to rdiff-backup
- _RsyncBinary_ - path to rsync
- _ZfsBinary_ - path to zfs
- _LockFile_ - change the default lock/pid file from
`$HOME/rdbduprunner.pid`
- _ExcludePath_ - What directory to look for exclude
files. Defaults to `/etc/rdbduprunner-excludes`
- _UseAgent_
- _TempDir_ - Passed to some binaries as an alternate temp dir
path. Defaults to not pass any temp options therefore probably uses
/tmp.
- _DefaultBackupDestination_ - Which backup destination to use if
none is specified.
- _MaxProcs_ - Maxiumum number of backups to run simultaneously.
- _MaxWait_ - Maxiumum number of seconds to wait for a host lock.

### BackupDestination Options

Items enclosed in a <BackupDestination X> configuration block. The
name of the block is referenced by the _DefaultBackupDestination_ global
option and the _BackupDestination_ config option inside BackupSet
blocks.

- _PercentUsed_ - Integer, optional

    Keep disk usage on destination below this percent:
    When using rdiff-backup and duplicty type backups rdbduprunner will
    attempt to delete older increments in order to keep usage below this
    percentage.  It will do so before running backups and will not run
    backups if it cannot reduce usage below this level.

- _MinFree_ - Integer, optional

    Keep disk usage below this number: When using rdiff-backup and
    duplicty type backups rdbduprunner will attempt to delete older
    increments in order to keep this much space free as specified in 512
    byte blocks (because I could reliably get df to report this value.) It
    will do so before running backups and will not run backups if it
    cannot free this much space.

- _Inplace_ - Boolean (true|t|yes|on|1), optional

    Passes the --inplace and --partial options to rsync for this
    destination.  Assumed to be false unless Inplace is set to one of the
    above parameters. Defaults to false.

### BackupSet Options

Items enclosed in a <BackupSet X> configuration block. The name of the
block is not referenced anywhere but should be unique or collisions
will occur.

- _BackupDestination_ - String, optional

    Must match existing BackupDestination as defined above.  When not
    specified the default will be used as specified in global options as
    DefaultBackupDestination.  These backups will be written to the the
    destination specified using the backup type and other options
    specified for that backup destination.

- _Path_ - String, mandatory (multiples ok)

    Directory to be backed up. This may be specified multiple times per
    backupset, and doing so will create multiple backups one for each path
    specified.

- _Host_ - String, optional

    Host to be backed up; if not specified assumes localhost

- _Inventory_ - Boolean (if present at all, assumed to be true!)

    Look at the remote machine for a list of directories to back up:
    Excludes a long list of non-filesystem type filesystems (fuse, etc.)
    Creates a new backup from each one not excluded.

- _Tag_ - String, optional

    Overrides the generated tag used to construct the output directory path.

- _Exclude_ - String, optional (multiples ok)

    Pass these paths to the --exclude or similar options of the underlying
    invocation of rdiff-backup, duplicity, or rsync.  Does not attempt to
    normalize the paths for any given method of specifiying exclusions.

- _MaxInc_ - Integer, optional

    Used by the --tidy option to remove all but the most recent X
    increments.

- _MaxAge_ - String, optional (rdiff-backup/duplicity only)

    Used by the --tidy option to remove all increments older than
    specified age.  Ultimately this is passed to the remove-older-than
    options of rdiff-backup or duplicity so see those manpages for
    details.

- _ZfsCreate_ - Boolean, optional

    Create a zfs for the path, if the directory doesn't already exist.
    Can be set at the BackupDestination level as well.

- _ZfsSnapshot_ - Boolean, optional

    Create a zfs snapshot of the destination path, if possible.
    Can be set at the BackupDestination level as well.

- _Inplace_ - Boolean (true|t|yes|on|1|false|f|no|off|0), optional

    Passes the --inplace and --partial options to rsync for this
    destination.  Assumed to be false unless Inplace is set to one of the
    above parameters. Defaults to false.
    Can be set at the BackupDestination level as well.

## `$HOME/rdbduprunner.pid`

Default PID/lock file.

# CAVEATS

# BUGS

# RESTRICTIONS

# NOTES

# AUTHOR

Aran Cox <arancox@gmail.com>

# HISTORY

# SEE ALSO

> rdiff-backup(1), duplicity(1), rsync(1), trickle(1), ssh(1), unison(1).
