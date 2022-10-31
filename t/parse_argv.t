# Before 'make install' is performed this script should be runnable with
# 'make test'. After 'make install' it should work as 'perl Backup-rdbduprunner.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;

use Test2::V0;
use Backup::rdbduprunner qw(:all);

use Data::Dumper;

sub big_globals {
    return {
        'calculate-average'     => $AVERAGE,
        cleanup                 => $CLEANUP,
        'check'                 => $CLEANUP,
        compare                 => $COMPARE,
        'verify'                => $COMPARE,
        'dump'                  => $DUMP,
        'list-oldest'           => $LISTOLDEST,
        'remove-oldest'         => $REMOVE,
        'status'                => $STATUS,
        'tidy'                  => $TIDY,
        'list'                  => $LIST,
        'orphans'               => $ORPHANS,
        'status_json'           => $STATUS_JSON,
        'status_delete'         => \@STATUS_DELETE,
        'force'                 => $FORCE,
        'full'                  => $FULL,
        'maxage'                => $MAXAGE,
        'maxinc'                => $MAXINC,
        'verbosity'             => $VERBOSITY,
        't'                     => $TVERBOSITY,
        'u'                     => $USEAGENT,
        'allow-source-mismatch' => $ALLOWSOURCEMISMATCH,
        'tempdir'               => $TEMPDIR,
        'v'                     => $VERBOSE,
        'progress'              => $PROGRESS,
        dryrun                  => $DRYRUN,
        stats                   => $STATS,
        'dest'                  => $DEST,
        'host'                  => $HOST,
        'path'                  => $PATH,
        'duplicity-binary'      => $DUPLICITY_BINARY,
        'rdiff-backup-binary'   => $RDIFF_BACKUP_BINARY,
        'rsync-binary'          => $RSYNC_BINARY,
        'zfs-binary'            => $ZFS_BINARY,
        'exclude-path'          => $EXCLUDE_PATH,
        'facility'              => $FACILITY,
        'level'                 => $LOG_LEVEL,
        'localhost'             => $LOCALHOST,
        'test'                  => $TEST,
        'skipfs'                => \@SKIP_FS,
        'allowfs'               => \@ALLOW_FS,
        'maxprocs'              => $MAXPROCS,
        'maxwait'               => $MAXWAIT,
        checksum                => $CHECKSUM,
        wholefile               => $WHOLEFILE,
        inplace                 => $INPLACE,
    };
}
my $defaults = {
    'calculate-average'     => 0,
    cleanup                 => 0,
    'check'                 => 0,
    compare                 => 0,
    'verify'                => 0,
    'dump'                  => 0,
    'list-oldest'           => 0,
    'remove-oldest'         => 0,
    'status'                => 0,
    'tidy'                  => 0,
    'list'                  => 0,
    'orphans'               => 0,
    'status_json'           => undef,
    'status_delete'         => [],
    'force'                 => 0,
    'full'                  => 0,
    'maxage'                => undef,
    'maxinc'                => undef,
    'verbosity'             => undef,
    't'                     => undef,
    'u'                     => undef,
    'allow-source-mismatch' => 0,
    'tempdir'               => undef,
    'v'                     => 0,
    'progress'              => 0,
    dryrun                  => 0,
    stats                   => undef,
    'dest'                  => undef,
    'host'                  => undef,
    'path'                  => undef,
    'duplicity-binary'      => undef,
    'rdiff-backup-binary'   => undef,
    'rsync-binary'          => undef,
    'zfs-binary'            => undef,
    'exclude-path'          => undef,
    'facility'              => 'user',
    'level'                 => 'info',
    'localhost'             => undef,
    'test'                  => 1,
    'skipfs'                => [
        qw(
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
            zfs)
    ],
    'allowfs'  => [],
    'maxprocs' => undef,
    'maxwait'  => undef,
    checksum   => undef,
    wholefile  => undef,
    inplace    => undef,
};

{
    my $cv = Config::Validator->new(%config_definition);

    my $results;
    $results = parse_argv([], \%get_options,\%cfg_def);
    ok(lives {
        $cv->validate($results,"cli");
    }, "unparaseable");
    is( $results,
        {},
        "nothing passed");
    is( big_globals(),
        $defaults,
        "no options global vars",
    );

    {
        local $STATS=$STATS;
        local $TEST=$TEST;
        $results = parse_argv([qw(--notest --stats)], \%get_options,\%cfg_def);
        ok(lives {
            $cv->validate($results,"cli");
        }, "unparaseable");
        is( $results,
            {},
            "nothing passed");
        $$defaults{test} = 0;
        $$defaults{stats} = 1;
        is( big_globals(),
            $defaults,
            "test and stats");
    }
    
    $results = parse_argv([
        qw(
              --calculate-average
              --cleanup
              --check
              --compare
              --verify
              --dump
              --list-oldest
              --remove-oldest
              --status
              --tidy
              --list
              --orphans
      )], \%get_options,\%cfg_def);
    ok(lives {
        $cv->validate($results,"cli");
    }, "unparaseable");
    is( $results,
        {},
        "nothing passed");
    $$defaults{test} = 1;
    $$defaults{stats} = undef;
    
    for(qw(calculate-average cleanup check verify compare dump list-oldest remove-oldest status tidy list orphans)) {
        $$defaults{$_} = 1;
    }
    is( big_globals(),
        $defaults,
        "major modes");

    # our $bh = {
    #     host              => 'server',
    #     btype             => 'rsync',
    #     backupdestination => 'default',
    #     path              => '/tmp',
    #     tag               => 'server-tmp',
    #     exclude           => ['nope'],
    #     excludes          => ['/etc/some/file'],
    #     src               => 'server:/tmp',
    #     dest              => '/some/where/server-tmp',
    # };
    # {
    #     local $bh = $bh;
    #     $$bh{disabled} = 1;
    #     is( build_backup_command($bh),
    #         undef,
    #         "disabled backup",
    #     );
    # }
    # %CONFIG = ( 'default' => { 'busted' => 1 });
    # is( build_backup_command($bh),
    #     undef,
    #     "busted backup destination this check is right but wrong"
    # );
    # $$bh{btype} = 'duplicity';
    # $FULL = 1;
    # $USEAGENT = 1;
    # $ALLOWSOURCEMISMATCH = 1;
    # $TEMPDIR = '/var/tmp';
    # $DUPLICITY_BINARY = 'duplicity';
    # $$bh{disabled} = 0;
    # $CONFIG{default}{busted}=0;

    # is([build_backup_command($bh)],
    #    [qw(duplicity full --use-agent --allow-source-mismatch --no-print-statistics --exclude-other-filesystems --tempdir /var/tmp --exclude-globbing-filelist /etc/some/file --exclude nope server:/tmp /some/where/server-tmp)],
    #    "full duplicity");
    # $$bh{signkey} = '0x400';
    # $$bh{encryptkey} = 'aran';
    # $$bh{stats} = 1;
    # $FULL = 0;
    # is([build_backup_command($bh)],
    #    [qw(duplicity --use-agent --allow-source-mismatch --sign-key 0x400 --encrypt-key aran --exclude-other-filesystems --tempdir /var/tmp --exclude-globbing-filelist /etc/some/file --exclude nope server:/tmp /some/where/server-tmp)],
    #    "not-full duplicity with extra opts");
    # $$bh{btype} = 'rdiff-backup';
    # $$bh{stats} = 0;
    # $RDIFF_BACKUP_BINARY = 'rdiff-backup';
    # is([build_backup_command($bh)],
    #    [qw(rdiff-backup --exclude-device-files --exclude-other-filesystems --no-eas --ssh-no-compression --tempdir /var/tmp --exclude-globbing-filelist /etc/some/file --exclude nope server:/tmp /some/where/server-tmp)],
    #    "rdiff-backup");
    # $$bh{sshcompress} = 1;
    # $$bh{stats} = 1;
    # is([build_backup_command($bh)],
    #    [qw(rdiff-backup --exclude-device-files --exclude-other-filesystems --no-eas --print-statistics --tempdir /var/tmp --exclude-globbing-filelist /etc/some/file --exclude nope server:/tmp /some/where/server-tmp)],
    #    "rdiff-backup");
    # $$bh{btype} = 'rsync';
    # $$bh{checksum} = 1;
    # $$bh{trickle} = 4;
    # $$bh{stats} = 0;
    
    # $DRYRUN = 1;
    # $RSYNC_BINARY='rsync';
    # $LOG_DIR = '/var/log';
    
    # is([build_backup_command($bh)],
    #    [qw(rsync --archive --one-file-system --hard-links --delete --delete-excluded --dry-run --checksum --sparse --bwlimit=4 -z --log-file=/var/log/server-tmp.log --temp-dir=/var/tmp --exclude-from=/etc/some/file --exclude nope server:/tmp /some/where/server-tmp)],
    #    "rsync dry-run");
    # $$bh{inplace} = 1;
    # $$bh{stats} = 1;
    # $$bh{wholefile} = 0;
    # $$bh{exclude} = [qw(nope not this)];
    # $DRYRUN = 0;

    # is([build_backup_command($bh)],
    #    [qw(rsync --archive --one-file-system --hard-links --delete --delete-excluded --no-whole-file --checksum --inplace --partial --bwlimit=4 -z --stats --log-file=/var/log/server-tmp.log --temp-dir=/var/tmp --exclude-from=/etc/some/file --exclude nope --exclude not --exclude this server:/tmp /some/where/server-tmp)],
    #    "rsync");
}

done_testing;
