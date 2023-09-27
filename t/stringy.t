# Before 'make install' is performed this script should be runnable with
# 'make test'. After 'make install' it should work as 'perl Backup-rdbduprunner.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;

use Test2::V0;
use Backup::rdbduprunner qw(&stringy $APP_NAME %databasetype_case );
$APP_NAME='bob';

#use Data::Dumper;

{
    is( Backup::rdbduprunner::tag_prio('severity'),-8);
    is( Backup::rdbduprunner::tag_prio('timestamp'),50);
    is( Backup::rdbduprunner::tag_prio('hostname'),-9);
    is( Backup::rdbduprunner::tag_prio('msg'),-5);
    is( Backup::rdbduprunner::tag_prio('no comment this is silly'),0);

    # cannot figour out how to test this:
    # is( [sort {&Backup::rdbduprunner::sort_tags} (qw( msg hostname timestamp ))],
    #     ['hostname','msg','timestamp'] );

    is( stringy(
        {
            'timestamp' => 'stump',
            'datetime' => 'now',
            'backupset' => 'fish',
            'backupdestination' => 'toast',
            'severity' => 'bad',
            'msg' => 'time for pants',
            'unknown' => "unktag",
            'hostname' => 'server',
            'tag' => 'taggy',
            'host' => 'server',
            'dest' => 'island',
            'gtag' => 'var',
            'btype' => 'restic',
        }
    ),
        'datetime="now" hostname="server" severity="bad" msg="time for pants" backupset="fish" bob_host="server" bob_tag="taggy" unknown="unktag" backupdestination="toast" btype="restic" dest="island" gtag="var" timestamp="stump"');
}
done_testing;
