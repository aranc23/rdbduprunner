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
        'u'                     => $USEAGENT,
        'allow-source-mismatch' => $ALLOWSOURCEMISMATCH,
        'tempdir'               => $TEMPDIR,
        dryrun                  => $DRYRUN,
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
    'u'                     => undef,
    'allow-source-mismatch' => 0,
    'tempdir'               => undef,
    dryrun                  => 0,
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
};

{
    $config_definition{cli} = { type => "struct",
                                fields => hashref_keys_drop(\%DEFAULT_CONFIG,'default','getopt'),
                            };
    my $cv = Config::Validator->new(%config_definition);
    my @options = hashref_key_array(\%DEFAULT_CONFIG,
                                    'getopt');
    my $results;
    $results = parse_argv([], \%get_options,@options);
    ok(lives { $cv->validate($results, 'cli'); }, 'unparaseable');
    is( $results,
        {},
        "nothing passed");
    is( big_globals(),
        $defaults,
        "no options global vars",
    );

    $results = parse_argv([qw(--notest --stats)], \%get_options,@options);
    ok(lives { $cv->validate($results, 'cli'); }, 'unparaseable');
    is( $results,
        {stats => 1},
        "options: notest and stats");
    $$defaults{test} = 0;
    is( big_globals(),
        $defaults,
        "old options: notest and stats");

    # start of "everything"
    $TEST = 1;
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
              --status-json
              --status-delete pork
              --force
              --full
              --maxage 1d
              --maxinc 4
              --verbosity 5
              -t 5
              -u
              --allow-source-mismatch
              --tempdir /var/tmp
              -v
              --progress
              --dry-run
              --wholefile
              --checksum
      )], \%get_options,@options);
    ok(lives {
        $cv->validate($results,"cli");
    }, "unparaseable");
    $$defaults{test} = 1;
    is( $results,
        {wholefile => 1,
         checksum => 1,
         terminalverbosity => 5,
         verbosity => 5,
         progress => 1,
         verbose => 1,
     },
        "nothing passed");

    for(qw(calculate-average cleanup check verify compare dump list-oldest remove-oldest status tidy list orphans status_json allow-source-mismatch dryrun force full u)) {
        $$defaults{$_} = 1;
    }
    $$defaults{'status_delete'} = [qw(pork)];
    $$defaults{'tempdir'} = '/var/tmp';
    $$defaults{'maxage'} = '1d';
    $$defaults{'maxinc'} = '4';

    is( big_globals(),
        $defaults,
        "everything");

}

done_testing;
