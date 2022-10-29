# Before 'make install' is performed this script should be runnable with
# 'make test'. After 'make install' it should work as 'perl Backup-rdbduprunner.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;

use Test2::V0;
use Backup::rdbduprunner qw(build_backup_command %CONFIG $FULL $USEAGENT $ALLOWSOURCEMISMATCH $TEMPDIR $DUPLICITY_BINARY $RDIFF_BACKUP_BINARY $DRYRUN $RSYNC_BINARY $LOG_DIR parse_config_backups $LOCALHOST $EXCLUDE_PATH);

use Data::Dumper;

{
    local *Backup::rdbduprunner::dlog = sub {};
    $LOCALHOST = 'a-lnx005';
    $EXCLUDE_PATH = '/etc/rdbduprunner/xxx';
    %CONFIG = (
        'backupset' => {
            'accx' => {
                'backupdestination' => 'restic',
                'path' => '/home/accx',
                'host' => 'a-lnx005.divms.uiowa.edu',
                'tag' => 'accx',
                'wholefile' => 0
            }
        },
        'backupdestination' => {
            'restic' => {
                'path' => '/home/accx/tmp/rsync',
                'type' => 'rsync'
            }
                                 }
    );
    is( [parse_config_backups()],
        [
            {
                'stats' => 1,
                'inplace' => 1,
                'path' => '/home/accx/',
                'checksum' => 0,
                'gtag' => 'generic-accx',
                'tag' => 'accx',
                'backupdestination' => 'restic',
                'exclude' => [],
                #'excludes' => [
                #    '/etc/rdbduprunner/excludes/generic'
                #],
                'wholefile' => 0,
                'btype' => 'rsync',
                'src' => '/home/accx/',
                'host' => 'a-lnx005.divms.uiowa.edu',
                'dest' => '/home/accx/tmp/rsync/accx'
            }
        ],
        "simple config",
    );
    %CONFIG = (
        'backupdestination' => {
            'data-tmp' => {
                'type' => 'rsync',
                'path' => '/data/tmp/rsync'
            }
        },
        'backupset' => {
            'test' => {
                'path' => '/home/spin/bin'
            }
        },
        'defaultbackupdestination' => 'data-tmp'
    );
    is( [parse_config_backups()],
        [
            {
                'btype' => 'rsync',
                'stats' => 1,
                'src' => '/home/spin/bin/',
                'checksum' => 0,
                'exclude' => [],
                'backupdestination' => 'data-tmp',
                'tag' => 'a-lnx005-home-spin-bin',
                'host' => 'a-lnx005',
                # 'excludes' => [
                #     '/etc/rdbduprunner/excludes/generic'
                # ],
                'inplace' => 1,
                'gtag' => 'generic-home-spin-bin',
                'dest' => '/data/tmp/rsync/a-lnx005-home-spin-bin',
                'path' => '/home/spin/bin/'
            }
        ],
        "skip the skips",
    );
    %CONFIG = (
        'backupset' => {
            'tick ' => {
                'host' => 'tick.physics.uiowa.edu',
                'path' => [
                    '/',
                    '/usr',
                    '/var',
                    '/home',
                    '/tmp'
                ],
                'inventory' => 0
            },
            'tock' => {
                'path' => [
                    '/',
                    '/home'
                ],
                'inventory' => 0,
                'host' => 'tock'
            }
        },
        'backupdestination' => {
            'scratch' => {
                'path' => '/scratch/backups'
            }
        },
        'defaultbackupdestination' => 'scratch'
    );
    $EXCLUDE_PATH = './tests';
    is( [ sort { $$a{dest} cmp $$b{dest} } parse_config_backups() ],
        [
            {
                'inventory' => 0,
                'path' => '/home/',
                'exclude' => [],
                'src' => 'tick.physics.uiowa.edu:/home/',
                'dest' => '/scratch/backups/tick.physics.uiowa.edu-home',
                'backupdestination' => 'scratch',
                'btype' => 'rsync',
                'excludes' => [
                    'tests/excludes/generic',
                    'tests/excludes/generic-home'
                ],
                'inplace' => 1,
                'stats' => 1,
                'host' => 'tick.physics.uiowa.edu',
                'checksum' => 0,
                'gtag' => 'generic-home',
                'tag' => 'tick.physics.uiowa.edu-home'
            },
            {
                'dest' => '/scratch/backups/tick.physics.uiowa.edu-root',
                'inventory' => 0,
                'src' => 'tick.physics.uiowa.edu:/',
                'exclude' => [],
                'path' => '/',
                'stats' => 1,
                'host' => 'tick.physics.uiowa.edu',
                'tag' => 'tick.physics.uiowa.edu-root',
                'checksum' => 0,
                'gtag' => 'generic-root',
                'backupdestination' => 'scratch',
                'btype' => 'rsync',
                'excludes' => [
                    'tests/excludes/generic',
                    'tests/excludes/generic-root'
                ],
                'inplace' => 1
            },
            {
                'inventory' => 0,
                'exclude' => [],
                'path' => '/tmp/',
                'src' => 'tick.physics.uiowa.edu:/tmp/',
                'dest' => '/scratch/backups/tick.physics.uiowa.edu-tmp',
                'backupdestination' => 'scratch',
                'btype' => 'rsync',
                'excludes' => [
                    'tests/excludes/generic'
                ],
                'inplace' => 1,
                'stats' => 1,
                'host' => 'tick.physics.uiowa.edu',
                'gtag' => 'generic-tmp',
                'tag' => 'tick.physics.uiowa.edu-tmp',
                'checksum' => 0
            },
            {
                'tag' => 'tick.physics.uiowa.edu-usr',
                'gtag' => 'generic-usr',
                'checksum' => 0,
                'host' => 'tick.physics.uiowa.edu',
                'stats' => 1,
                'inplace' => 1,
                'excludes' => [
                    'tests/excludes/generic',
                    'tests/excludes/generic-usr'
                ],
                'btype' => 'rsync',
                'backupdestination' => 'scratch',
                'dest' => '/scratch/backups/tick.physics.uiowa.edu-usr',
                'exclude' => [],
                'path' => '/usr/',
                'src' => 'tick.physics.uiowa.edu:/usr/',
                'inventory' => 0
            },
            {
                'backupdestination' => 'scratch',
                'btype' => 'rsync',
                'excludes' => [
                    'tests/excludes/generic',
                    'tests/excludes/generic-var'
                ],
                'inplace' => 1,
                'stats' => 1,
                'host' => 'tick.physics.uiowa.edu',
                'gtag' => 'generic-var',
                'checksum' => 0,
                'tag' => 'tick.physics.uiowa.edu-var',
                'inventory' => 0,
                'exclude' => [],
                'path' => '/var/',
                'src' => 'tick.physics.uiowa.edu:/var/',
                'dest' => '/scratch/backups/tick.physics.uiowa.edu-var'
            },
            {
                'exclude' => [],
                'path' => '/home/',
                'src' => 'tock:/home/',
                'inventory' => 0,
                'dest' => '/scratch/backups/tock-home',
                'inplace' => 1,
                'excludes' => [
                    'tests/excludes/generic',
                    'tests/excludes/generic-home'
                ],
                'btype' => 'rsync',
                'backupdestination' => 'scratch',
                'tag' => 'tock-home',
                'checksum' => 0,
                'gtag' => 'generic-home',
                'host' => 'tock',
                'stats' => 1
            },
            {
                'exclude' => [],
                'path' => '/',
                'src' => 'tock:/',
                'inventory' => 0,
                'dest' => '/scratch/backups/tock-root',
                'inplace' => 1,
                'excludes' => [
                    'tests/excludes/generic',
                    'tests/excludes/generic-root'
                ],
                'btype' => 'rsync',
                'backupdestination' => 'scratch',
                'tag' => 'tock-root',
                'checksum' => 0,
                'gtag' => 'generic-root',
                'host' => 'tock',
                'stats' => 1
            }
        ],
        "tick-tock",
    );
}

done_testing;
