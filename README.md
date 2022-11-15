# NAME

rdbduprunner - perl magic wrapper for rsync, rdiff-backup, and duplicity

# SYNOPSIS

**rdbduprunner** {**-h|--help**}

**rdbduprunner** {**--calculate-average|--check|--cleanup|--compare|--verify|--dump|--list|--list-oldest|--orphans|--remove-oldest|--status|--tidy|--status-json|--status-delete=_backup_**} {**-t|--terminal-verbosity** _integer_} {**-v|--verbose**} {**--progress**} {**--full**} {**--force**} {**--allow-source-mismatch**} {**-n|--dry-run**} {**--dest** _regex_} {**--host** _regex_} {**--path** _regex_}

# DESCRIPTION

rdbduprunner is a wrapper for rsync, rdiff-backup, and duplicity
backups.  rdbduprunner will look for configuration files in a short
list of standard locations as detailed under FILES.  These files are
parsed by Config::General which supports an Apache-like config file.

General usage involves running rdbduprunner with no options which will
only print out warnings and the commands that would be invoked if you
were to run it with the --notest option. Then run it again with the
\--notest option to actually perform the backups

Other common options involve filtering which backups to run, adjusting
the verbosity of the output, adjusting logging, and so on.

# OPTIONS

## MAJOR MODES

rdbduprunner's primary mode is "backup" and the following override
that; only one of the following is allowed for any invocation of
rdbduprunner.  Many only apply to one or both of rdiff-backup or
duplicity since they act on archives of their own creation.  For rsync
backups tools like ls and du perform similar functions.

- {**--status-json**}

    Prints the status DBM as a json hash for parsing by other tools.

- {**--status-delete**=_backup\_src_}

    Deletes the specified keys from the status DBM thus making
    rdbduprunner "forget" about them.  Does not change in any way what
    rdbduprunner will back up in the future, only alters the status
    database used by monitoring tools (cmk).

    IE: rdbduprunner --status-delete /local/ --status-delete /home/

    Can be specified multiple times.

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

## COMMAND LINE ONLY OPTIONS

Some options do not have equivalent configuration file parameters,
those are documented below.  Many parameters can be configured via
command line and config file and those are documented in the following
sections.

- {**--test**|**--notest**}

    The default invocation assumes --test which causes rdbduprunner to
    print which commands it would run without running them.  Passing
    \--notest will cause rdbduprunner to run the backup commands.

- {**--dest** _regex_}

    This option causes the backups to be run to be filtered based on the
    name of the BackupDestination.

- {**--host** _regex_}

    This option causes the backups to be run to be filtered based on the
    Host.

- {**--path** _regex_}

    This option causes the backups to be run to be filtered based on the
    path on the host to be backed up.

- {**-t|--terminal-verbosity** _integer_} (rdiff-backup only)

    Increases logging verbosity to the terminal with rdiff-backup.

- {**-v|--verbose**} (rsync only)

    Passes -v to rsync invocations.

- {**--progress**} (rsync only)

    Passes --progress to rsync invocations.

- {**--full**} (duplicity only)

    Passess the full option to duplicity backup.

- {**--force**} (duplicity only)

    Passess the --force option to duplicity cleanup mode.

- {**--config|config-file|config\_file** _path_}

    Load the specified configuration file(s).  If this option is specified
    the the default confguration files and configuration directory will
    not be loaded.

    See [FILES](https://metacpan.org/pod/FILES) for further explanation.

- {**--confd|conf-d|config\_d** _path_}

    Load all the config files in the specfied directory.  If this option
    is specified then the default configuration files and configuration
    directory will not be loaded.

    See [FILES](https://metacpan.org/pod/FILES) for further explanation.

- {**--allow-source-mismatch**} (duplicity only)

    Passes the identical option to duplicity.  No affect on other backup
    types.

- {**-n|--dry-run**} (rsync and duplicity only)

    Passes the --dry-run option to rsync or duplicity.  rdbduprunner will
    not run the prerun, postrun or zfs create and zfs snapshot commands
    (when applicable.)  rdiff-backup does not have a dry-run option.

## CONFIGURATION FILE PARAMETERS

Configuration files for rdbduprunner have 3 sections: global options,
backupsets and backupdestinations.  Many configuration parameters are
valid at the top level and inside backups and backupdestination
defintions.

For an overview of the configuration file format see the ["FILES"](#files) section.

- `Stats` _yes|no|on|off|0|1|true|false_ {**--stats|--no-stats**}

    All backup binaries supported by rdbduprunner have the option to
    produce some kind of statistics after a run.  Setting this to false
    will turn those options off.

    Default: true

- `Verbosity` _Integer_ {**--verbosity** _integer_} (rdiff-backup and duplicity)

    Increases logging verbosity to the rdiff-backup log file and adjusts
    the logging verbosity to the terminal for duplicity.

    Validity: CLI, Global, BackupDestination, BackupSet

- `WholeFile` _yes|no|on|off|0|1|true|false_ {**--whole-file|--wholefile|--no-whole-file|--no-wholefile**} (rsync only)

    When true, pass --whole-file to rsync.
    When false, pass --no-whole-file to rsync.

    Default: false

    Validity: CLI, Global, BackupDestination, BackupSet

- `Facility` _auth|authpriv|cron|daemon|kern|local\[0-7\]|mail|news|syslog|user|uucp_ {**--facility** _user|daemon|..._}

    Changes the facility as passed to [Log::Dispatch::Syslog](https://metacpan.org/pod/Log%3A%3ADispatch%3A%3ASyslog)

    Default: user

    Validity: CLI, Global

- `Level` _debug|info|notice|warning|error|critical|alert|emergency_ {**--level** _debug|info|..._}

    Syslog minimum severity level which is passed to the logging
    dispatcher. Log messages of the specified severity or greater will be
    logged to syslog, stdout, and the rdbduprunner log file.

    Default: info

    Validity: CLI, Global

- `GPGPassPhrase` _string_ (duplicity only)

    Used to set PASSPHRASE environment variable which is used by duplicity.

    Validity: Global BackupDestination

- `AWSAccessKeyID` _string_ (duplicity only)

    Used to set AWS\_ACCESS\_KEY\_ID environment variable which is used by duplicity.

    Validity: Global BackupDestination

- `AWSSecretAccessKey` _string_ (duplicity only)

    Used to set AWS\_SECRET\_ACCESS\_KEY environment variable which is used by duplicity.

    Validity: Global BackupDestination

- `SignKey` _keyid_ (duplicity only)

    Passed to duplicity using the --sign-key command line option.

    Validity: Global BackupDestination

- `EncryptKey` _keyid_ (duplicity only)

    Passed to duplicity using the --encrypt-key command line option.

    Validity: Global BackupDestination

- `Trickle` _integer_ {**--trickle** _integer_}

    For rsync backups this value is passed to the --bwlimit option.

    For other backup types, the backup software is invoked with
    `/usr/bin/trickle -s -u X`, which should serve to limit the usable
    bandwidth.

    Validity: CLI, Global, BackupDestination, BackupSet

- `ZfsCreate` _yes|no|on|off|0|1|true|false_

    Create a zfs for the path, if the directory doesn't already exist.

    Validity: Global BackupDestination

- `ZfsSnapshot` _yes|no|on|off|0|1|true|false_

    Create a zfs snapshot of the destination path, if possible.

- `Inplace` _yes|no|on|off|0|1|true|false_ {**--inplace|--no-inplace|--noinplace**

    Passes the --inplace and --partial options to rsync (instead of
    \--sparse) for this destination.  Assumed to be true every day of the
    week except Sunday unless explicitly set.  If you always want
    \--inplace, set this to true, if you always want --sparse set this to
    false.

- `Checksum` _yes|no|on|off|0|1|true|false_ {**-c|--checksum|--no-checksum**} (rsync only)

    Passes the --checksum (-c) option to rsync.

    Validity: CLI, Global, BackupDestination, BackupSet

- `SSHCompress` _yes|no|on|off|0|1|true|false_ {**--sshcompress|--no-sshcompress**} (rdiff-backup only)

    Passes --ssh-no-compression if set to a false value.

    This also mistakenly I believe passes -z to rsync to disable compression.

    Validity: CLI, Global, BackupDestination, BackupSet

- `DuplicityBinary` _executable_ {**--duplicity-binary** _executable_}

    Default: duplicity

    Validity: CLI, Global, BackupDestination, BackupSet

- `RsyncBinary` _executable_ {**--rsync-binary** _executable_}

    Default: rsync

    Validity: CLI, Global, BackupDestination, BackupSet

- `RdiffBackupBinary` _executable_ {**--rdiff-backup-binary** _executable_}

    Default: rdiff-backup

    Validity: CLI, Global, BackupDestination, BackupSet

- `ZfsBinary` _executable_ {**--zfs-binary** _executable_}

    Default: zfs

    Validity: CLI, Global, BackupDestination, BackupSet

- `TrickleBinary` _executable_ {**--trickle-binary** _executable_}

    Default: trickle

    Validity: CLI, Global, BackupDestination, BackupSet

- `MaxWait` _integer_ {**--maxwait** _integer_}

    Maximum number of seconds to wait for a lock on any given per-host
    lock file or the global per-process lock file.

    Default: 86400

    Validity: CLI, Global

- `DefaultBackupDestination` _backupdestinationname_

    Specify the name of the backupdestination to use if one isn't
    specified in the BackupSet.  Can only be specified in the config file
    at the type level.

    Validity: Global

- `MaxInc` _integer_ {**--maxinc** _integer_} (rdiff-backup only)

    Used by the --tidy option to remove all but the most recent X
    increments.

    Validity: CLI, Global, BackupDestination, BackupSet

- `MaxAge` _timespec_ {**--maxage** _timespec_} (rdiff-backup/duplicity only)

    Used by the --tidy option to remove all increments older than
    specified age.  Ultimately this is passed to the remove-older-than
    options of rdiff-backup or duplicity so see those manpages for
    details.

    Validity: CLI, Global, BackupDestination, BackupSet

    Example: MaxAge 1Y2W4D7s

- `SkipFSType` _fstype_ {**--skipfstype** _fstype_}

    Only applies during inventory, skips every filesystem with the types specified.
    Currently there is a default list and you can only add to it, not reset it.

    \--skipfs reiserfs

    Validity: CLI, Global, BackupDestination, BackupSet

    Default list:

    >     autofs
    >     binfmt\_misc
    >     bpf
    >     cgroup
    >     cgroup2
    >     cifs
    >     configfs
    >     debugfs
    >     devpts
    >     devtmpfs
    >     efivarfs
    >     exfat
    >     fuse
    >     fuse.encfs
    >     fuse.glusterfs
    >     fuse.gvfs-fuse-daemon
    >     fuse.gvfsd-fuse
    >     fuse.lxcfs
    >     fuse.portal
    >     fuse.sshfs
    >     fuse.vmware-vmblock
    >     fuse.xrdp-chansrv
    >     fuseblk
    >     fusectl
    >     htfs
    >     hugetlbfs
    >     ipathfs
    >     iso9660
    >     mqueue
    >     nfs
    >     nfs4
    >     nfsd
    >     nsfs
    >     ntfs
    >     proc
    >     pstore
    >     rootfs
    >     rpc\_pipefs
    >     securityfs
    >     selinuxfs
    >     squashfs
    >     sysfs
    >     tmpfs
    >     tracefs
    >     usbfs
    >     vfat
    >     zfs

- `AllowFS` _fstype_ {**--allowfs** _fstype_}

    Allows this filesystem type to be included during inventory.  When
    AllowFS is used, the skipfstype list is disregarded.  Only filesystem
    types specified this way will be included during inventory if any are
    specified at all. Because the default is for this parameter to be an
    empty list, the SkipFSType list will be used to exclude.

    Example: --allowfs reiserfs --allowfs ext4

    Validity: CLI, Global, BackupDestination, BackupSet

- `Skip` _path_ {**--skip** _path_}

    If a path added via the inventory process matches exactly the string
    or strings specified by a Skip option, rdbduprunner will not back up that
    filesystem/mountpoint. The following configuration fragment will cause
    rdbduprunner to backup all filesystems except /tmp `if` and only if /tmp
    is a seperate filesystem.  It does not work as an exclude directive
    above, it only matches filesystem mount points:

        Inventory true
        Skip /tmp

    Validity: CLI, Global, BackupDestination, BackupSet

- `SkipRE` _path_ {**--skipre** _path_}

    If a path added via the inventory process matches the string specified
    by a SkipRE option when treated as a regular expression, rdbduprunner
    will not not back up that filesystem/mountpoint. The following
    configuration fragment will cause rdbduprunner to back up all
    filesystems except filesystems mounted under /mnt, but only if they
    are a seperate unique filesystem added via inventory:

        Inventory true
        SkipRE /mnt/.+

    If there is a directory, in this example, like /mnt/test it will still
    be backed up unless it it's own mountpoint.  It does not work as an
    exclude directive as documented above above, it only matches
    filesystem mount points

    Validity: CLI, Global, BackupDestination, BackupSet

- `LocalHost` _hostname_ {**--localhost** _hostname_}

    rdbduprunner sets this to the shortname of the system.  This is then
    used when setting the `host` parameter for BackupSets that don't
    specify one.  The host value is then used in generating the output
    path of the backup programs.  This means that purely local backups
    will have names like `server1-home` and remote systems if you specify
    the FQDN will have output directories named like:
    `server1.example.com-home`.

    This should probably be the output of the hostname() sub from
    [Sys::Hostname](https://metacpan.org/pod/Sys%3A%3AHostname) by default, however changing it now would change the
    names of some backups, at least potentially.

    See [https://github.com/aranc23/rdbduprunner/issues/12](https://github.com/aranc23/rdbduprunner/issues/12)

    Advice: don't change this.

    Validity: CLI, Global

- `UseAgent` _yes|no|on|off|0|1|true|false_ {**--use-agent|--useagent**} (duplicity only)

    Passes the --use-agent option to duplicity.

    Validity: CLI, Global, BackupDestination, BackupSet

- `ExcludePath` _path_ {**--exclude-path** _path_}

    rdbduprunner will look in this directory for a sub-directory named
    rdb-excludes or excludes and match the backup tags with files.  rsync
    and rdiff-backup/duplicity have different syntax for their exclude
    files which is why they are seperated.  See the man pages for details.
    This is a poorly thoughtout and confusing feature so maybe don't use
    it.

    Default: /etc/rdbduprunner.

    Validity: CLI, Global

- `maxprocs` _integer_ {**--maxprocs** _integer_}

    Maximum number of simultaneous backups to perform.  rdbduprunner will
    never do more than one backup from any given host at a time but if
    there are multiple hosts multiple backups should occur at once.

    Default: 1

- `tempdir` _path_ {**--tempdir|--temp-dir** _path_}

    Pass to underlying backup programs, if set.

    Validity: CLI, Global

- `prerun` _command_

    Command to run _before_ each backup is executed.  If this command
    fails (exits with any error code other than 0) then the backup will
    bot be run.  Various environment variables will be set before
    executing the prerun command.  See the [ENVIRONMENT](https://metacpan.org/pod/ENVIRONMENT) section for
    details.

    Validity: Global BackupDestination BackupSet

- `postrun` _command_

    Command to run _after_ each backup is executed.  If the backup
    command fails, this command will bot be run.  Various environment
    variables will be set before executing the postrun command.  See the
    [ENVIRONMENT](https://metacpan.org/pod/ENVIRONMENT) section for details.

    Validity: Global BackupDestination BackupSet

- `volsize` _integer_ {**--volsize** _integer_} (duplicity)

    Passed to the duplicity --volsize option.

    Validity: CLI Global BackupDestination BackupSet

# RETURN VALUE

# ERRORS

# DIAGNOSTICS

# EXAMPLES

# ENVIRONMENT

Before executing the post and pre run commands, the following
environment variables will be set:

- RDBDUPRUNNER\_BACKUP\_src
- RDBDUPRUNNER\_BACKUP\_dest
- RDBDUPRUNNER\_BACKUP\_tag
- RDBDUPRUNNER\_BACKUP\_path
- RDBDUPRUNNER\_BACKUP\_host

These values are taken from the details of the backup being performed.

# FILES

## `$HOME/.local/state/rdbduprunner.pid` `/run/rdbduprunner.pid`

Default PID/lock file.

## Command Line Specified Configuration Files

If the --config or --confd options are specified, only those files and
directories will be loaded.  The default configuration files will not
be loaded in this case.

## Legacy Configuration Files

If no command line overrides are specified and a legacy configuration
file exists, rbdduprunner will load the legacy config file. The
default configuration files will not be loaded in this case.

These legacy files are:

- /etc/rdbduprunner.rc (root only)
- ~/.rdbduprunner.rc

## Default Configuration Files:

In the absence of legacy config files and command line overrides the
following configuration files will be loaded for root:

- /etc/rdbduprunner/rdbduprunner.\*
- /etc/rdbduprunner/conf.d/\*

For non-root users:

- ~/.config/rdbduprunner/rdbduprunner.\*
- ~/.config/rdbduprunner/conf.d/\*

rdbduprunner's legacy config file is an Apache style config file parsed by
the Config::General perl module.

Configuration files specified via the command line option or those
loaded by default are loaded by Config::Any and therefore can be in
any format recogized by the module, provided the extension matches the
contents.  (ie: .yaml for yaml files)

Regardless of the parser the configuration files consist of global options,
BackupDestinations and BackupSets.  The options names are case
insensitive. Options are generally honored in this order:

The precendence is as follows:

- Command Line Options
- BackupSet
- BackupDestination
- Global Options
- Defaults

Options that can be specified at multiple levels are documented above
in ["CONFIGURATION FILE PARAMETERS"](#configuration-file-parameters).  Configuration items than only be
specified inside a backupset or backupdestination configuration item
are documented below.

### BackupDestination Options

Items enclosed in a <BackupDestination X> configuration block. The
name of the block is referenced by the _DefaultBackupDestination_ global
option and the _BackupDestination_ config option inside BackupSet
blocks.

- `path` _string_

    This is the destination component passed to the backup command.  In
    most cases, it's simply a path but duplicity can use other backends.

- `type` _rdiff-backup|rsync|duplicity_

    Determines what backup software to use when writting to this
    backupdestination.

    Default: rsync

- `PercentUsed` _Integer_

    Keep disk usage on destination below this percent:
    When using rdiff-backup and duplicty type backups rdbduprunner will
    attempt to delete older increments in order to keep usage below this
    percentage.  It will do so before running backups and will not run
    backups if it cannot reduce usage below this level.

- `MinFree` - _Integer_

    Keep disk usage below this number: When using rdiff-backup and
    duplicty type backups rdbduprunner will attempt to delete older
    increments in order to keep this much space free as specified in 512
    byte blocks (because I could reliably get df to report this value.) It
    will do so before running backups and will not run backups if it
    cannot free this much space.

### BackupSet Options

Items enclosed in a <BackupSet X> configuration block. The name of the
block is not referenced anywhere but should be unique or collisions
will occur.

- `BackupDestination` _name_

    Must match existing BackupDestination as defined above.  When not
    specified the default will be used as specified in global options as
    DefaultBackupDestination.  These backups will be written to the the
    destination specified using the backup type and other options
    specified for that backup destination.

- `Path` _path_

    Directory to be backed up. This may be specified multiple times per
    backupset, and doing so will create multiple backups one for each path
    specified.

- `Host` _hostname or ip address_

    Host to be backed up; if not specified assumes localhost

- `Inventory` _true|false|yes|no|on|off|0|1_

    Look at the remote machine for a list of directories to back up:
    Excludes a long list of non-filesystem type filesystems (fuse, etc.)
    Creates a new backup from each one not excluded.

- `Tag` _string_

    Overrides the generated tag used to construct the output directory
    path.  This affects the name of the directory to write the backups to,
    underneath that specified by the backupdestination.  Overriding this
    tag could have some weird side effects.  Do not use this option with
    multiple Path directives or with the inventory option.

- `Exclude` _string_

    Pass these paths to the --exclude or similar options of the underlying
    invocation of rdiff-backup, duplicity, or rsync.  Does not attempt to
    normalize the paths for any given method of specifiying exclusions.

- `disabled` _true|false|yes|no|on|off|0|1_

    Do not perform the backups in this BackupSet.

# CAVEATS

# BUGS

# RESTRICTIONS

# NOTES

rdbduprunner prefers to use configuration items in the following order
with later entries superseding the prior level. This assumes that the
option itself is applicable all the way down to the individual
invocations of the backup software.  The Validity entry for each
configuration option indicates which level the options are valid at.

- Global Configuration
- BackupDestination
- BackupSet
- Command Line Options

# AUTHOR

Aran Cox <arancox@gmail.com>

# HISTORY

# SEE ALSO

> [rdiff-backup(1)](http://man.he.net/man1/rdiff-backup), [duplicity(1)](http://man.he.net/man1/duplicity), [rsync(1)](http://man.he.net/man1/rsync), [trickle(1)](http://man.he.net/man1/trickle), [ssh(1)](http://man.he.net/man1/ssh), [unison(1)](http://man.he.net/man1/unison).
