# Before 'make install' is performed this script should be runnable with
# 'make test'. After 'make install' it should work as 'perl Backup-rdbduprunner.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;

use Test2::V0;
use Backup::rdbduprunner qw(build_backup_command %CONFIG $FULL $USEAGENT $ALLOWSOURCEMISMATCH $TEMPDIR $DUPLICITY_BINARY);

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
    };
    {
        local $bh = $bh;
        $$bh{disabled} = 1;
        is( build_backup_command($bh),
            undef,
            "disabled backup",
        );
    }
    %CONFIG = ( 'default' => { 'busted' => 1 });
    is( build_backup_command($bh),
        undef,
        "busted backup destination this check is right but wrong"
    );
    $$bh{btype} = 'duplicity';
    $FULL = 1;
    $USEAGENT = 1;
    $ALLOWSOURCEMISMATCH = 1;
    $TEMPDIR = '/var/tmp';
    $DUPLICITY_BINARY = 'duplicity';
    $$bh{disabled} = 0;
    $CONFIG{default}{busted}=0;

    is([build_backup_command($bh)],
       [qw(duplicity full --use-agent --allow-source-mismatch --no-print-statistics --exclude-other-filesystems --tempdir /var/tmp --exclude-globbing-filelist /etc/some/file --exclude nope server:/tmp /some/where/server-tmp)],
       "full duplicity");
    $$bh{signkey} = '0x400';
    $$bh{encryptkey} = 'aran';
    $$bh{stats} = 1;
    $FULL = 0;
    is([build_backup_command($bh)],
       [qw(duplicity --use-agent --allow-source-mismatch --sign-key 0x400 --encrypt-key aran --exclude-other-filesystems --tempdir /var/tmp --exclude-globbing-filelist /etc/some/file --exclude nope server:/tmp /some/where/server-tmp)],
       "not-full duplicity with extra opts");
}

done_testing;
