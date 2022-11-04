# Before 'make install' is performed this script should be runnable with
# 'make test'. After 'make install' it should work as 'perl Backup-rdbduprunner.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;

use Test2::V0;
use Backup::rdbduprunner qw(build_backup_command %CONFIG $TEMPDIR $DRYRUN $LOG_DIR %CLI_CONFIG);

use Data::Dumper;



{
    local *Backup::rdbduprunner::dlog = sub {};
    our $bh = {
        host              => 'server',
        btype             => 'rsync',
        backupdestination => 'default',
        path              => '/tmp',
        tag               => 'server-tmp',
        exclude           => ['nope'],
        excludes          => ['/etc/some/file'],
        src               => 'server:/tmp',
        dest              => '/some/where/server-tmp',
        progress          => 1,
        verbose           => 1,
        verbosity         => 5,
        terminalverbosity => 9,
        duplicitybinary   => 'duplicity',
        rsyncbinary       => 'rsync',
        rdiffbackupbinary => 'rdiff-backup',
    };
    { # disabled backup
        local $bh = $bh;
        $$bh{disabled} = 1;
        is( build_backup_command($bh),
            undef,
            "disabled backup",
        );
    }
    # start of "busted backup destination this check is right but wrong"
    %CONFIG = ( 'default' => { 'busted' => 1 });
    is( build_backup_command($bh),
        undef,
        "busted backup destination this check is right but wrong"
    );

    # start of "full duplicity"
    $$bh{btype} = 'duplicity';
    $CLI_CONFIG{'full'} = 1;
    $$bh{useagent} = 1;
    $$bh{allowsourcemismatch} = 1;
    $TEMPDIR = '/var/tmp';
    $$bh{disabled} = 0;
    $CONFIG{default}{busted}=0;

    is([build_backup_command($bh)],
       [qw(duplicity --verbosity 5 full --use-agent --allow-source-mismatch --no-print-statistics --exclude-other-filesystems --tempdir /var/tmp --exclude-globbing-filelist /etc/some/file --exclude nope server:/tmp /some/where/server-tmp)],
       "full duplicity");

    # start of "not-full duplicity with extra opts"
    $$bh{signkey} = '0x400';
    $$bh{encryptkey} = 'aran';
    $$bh{stats} = 1;
    delete $CLI_CONFIG{'full'};
    is([build_backup_command($bh)],
       [qw(duplicity --verbosity 5 --use-agent --allow-source-mismatch --sign-key 0x400 --encrypt-key aran --exclude-other-filesystems --tempdir /var/tmp --exclude-globbing-filelist /etc/some/file --exclude nope server:/tmp /some/where/server-tmp)],
       "not-full duplicity with extra opts");

    # start of "rdiff-backup"
    $$bh{btype} = 'rdiff-backup';
    $$bh{stats} = 0;
    is([build_backup_command($bh)],
       [qw(rdiff-backup --verbosity 5 --terminal-verbosity 9 --exclude-device-files --exclude-other-filesystems --no-eas --ssh-no-compression --tempdir /var/tmp --exclude-globbing-filelist /etc/some/file --exclude nope server:/tmp /some/where/server-tmp)],
       "rdiff-backup");

    # start of "rdiff-backup with stats"
    $$bh{sshcompress} = 1;
    $$bh{stats} = 1;
    is([build_backup_command($bh)],
       [qw(rdiff-backup --verbosity 5 --terminal-verbosity 9 --exclude-device-files --exclude-other-filesystems --no-eas --print-statistics --tempdir /var/tmp --exclude-globbing-filelist /etc/some/file --exclude nope server:/tmp /some/where/server-tmp)],
       "rdiff-backup with stats");

    # start of "rdiff-backup with stats and disable ssh compression"
    $$bh{sshcompress} = 0;
    $$bh{rdiffbackupbinary} = '/opt/bin/rdiff-backup';
    is([build_backup_command($bh)],
       [qw(/opt/bin/rdiff-backup --verbosity 5 --terminal-verbosity 9 --exclude-device-files --exclude-other-filesystems --no-eas --ssh-no-compression --print-statistics --tempdir /var/tmp --exclude-globbing-filelist /etc/some/file --exclude nope server:/tmp /some/where/server-tmp)],
       "rdiff-backup with stats and disable ssh compression");

    # start of "rsync"
    $$bh{btype} = 'rsync';
    $$bh{checksum} = 1;
    $$bh{trickle} = 4;
    $$bh{stats} = 0;
    $$bh{sshcompress} = 1;

    $DRYRUN = 1;
    $LOG_DIR = '/var/log';

    is([build_backup_command($bh)],
       [qw(rsync --progress --verbose --archive --one-file-system --hard-links --delete --delete-excluded --dry-run --checksum --sparse --bwlimit=4 -z --log-file=/var/log/server-tmp.log --temp-dir=/var/tmp --exclude-from=/etc/some/file --exclude nope server:/tmp /some/where/server-tmp)],
       "rsync dry-run");
    $$bh{inplace} = 1;
    $$bh{stats} = 1;
    $$bh{wholefile} = 0;
    $$bh{exclude} = [qw(nope not this)];
    $DRYRUN = 0;

    is([build_backup_command($bh)],
       [qw(rsync --progress --verbose --archive --one-file-system --hard-links --delete --delete-excluded --no-whole-file --checksum --inplace --partial --bwlimit=4 -z --stats --log-file=/var/log/server-tmp.log --temp-dir=/var/tmp --exclude-from=/etc/some/file --exclude nope --exclude not --exclude this server:/tmp /some/where/server-tmp)],
       "rsync");
}

done_testing;
