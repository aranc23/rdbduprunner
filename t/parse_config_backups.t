# Before 'make install' is performed this script should be runnable with
# 'make test'. After 'make install' it should work as 'perl Backup-rdbduprunner.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;

use Test2::V0;
use Backup::rdbduprunner qw(build_backup_command %CONFIG $USEAGENT $ALLOWSOURCEMISMATCH $TEMPDIR $DRYRUN $LOG_DIR parse_config_backups $EXCLUDE_PATH %CLI_CONFIG %DEFAULT_CONFIG);

use Data::Dumper;

{
    local *Backup::rdbduprunner::dlog = sub {};
    $CLI_CONFIG{localhost} = 'a-lnx005';
    $EXCLUDE_PATH = '/etc/rdbduprunner/xxx';
    is( [parse_config_backups(\%DEFAULT_CONFIG,
                              {
                                  'backupset' => {
                                      'accx' => {
                                          'backupdestination' => 'restic',
                                          'path' => '/home/accx',
                                          'host' => 'a-lnx005.divms.uiowa.edu',
                                          'tag' => 'accx',
                                          'wholefile' => 0,
                                          'inplace' => 0,
                                      }
                                  },
                                  'backupdestination' => {
                                      'restic' => {
                                          'path' => '/home/accx/tmp/rsync',
                                          'type' => 'rsync'
                                      }
                                  },
                              },
                              \%CLI_CONFIG),
                          ],
        [
            {
                'stats' => 1,
                'inplace' => 0,
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
                'dest' => '/home/accx/tmp/rsync/accx',
                'progress' => 0,
                'verbose' => 0,
                'rdiffbackupbinary' => 'rdiff-backup',
                'duplicitybinary' => 'duplicity',
                'tricklebinary' => 'trickle',
                'zfsbinary' => 'zfs',
                'rsyncbinary' => 'rsync',
            }
        ],
        "simple config",
    );
    is( [   parse_config_backups(
                \%DEFAULT_CONFIG,
                {   'backupdestination' => {
                        'data-tmp' => {
                            'type' => 'rsync',
                            'path' => '/data/tmp/rsync'
                        }
                    },
                    'backupset' => {
                        'test' => {
                            'path'    => '/home/spin/bin',
                            'inplace' => 1,
                        }
                    },
                    'defaultbackupdestination' => 'data-tmp'
                },
                \%CLI_CONFIG,
            )
        ],
        [   {   'btype'             => 'rsync',
                'stats'             => 1,
                'src'               => '/home/spin/bin/',
                'checksum'          => 0,
                'exclude'           => [],
                'backupdestination' => 'data-tmp',
                'tag'               => 'a-lnx005-home-spin-bin',
                'host'              => 'a-lnx005',
                'inplace'           => 1,
                'gtag'              => 'generic-home-spin-bin',
                'dest'              => '/data/tmp/rsync/a-lnx005-home-spin-bin',
                'path'              => '/home/spin/bin/',
                'progress' => 0,
                'verbose' => 0,
                'rdiffbackupbinary' => 'rdiff-backup',
                'duplicitybinary' => 'duplicity',
                'tricklebinary' => 'trickle',
                'zfsbinary' => 'zfs',
                'rsyncbinary' => 'rsync',
            }
        ],
        "skip the skips",
    );
    is( [   parse_config_backups(
                \%DEFAULT_CONFIG,
                {   'backupdestination' => {
                        'data-tmp' => {
                            'type' => 'rsync',
                            'path' => '/data/tmp/rsync'
                        }
                    },
                    'backupset' => {
                        'test' => {
                            'path'     => '/home/spin/bin',
                            'inplace'  => 1,
                            'checksum' => 1,
                        }
                    },
                    'defaultbackupdestination' => 'data-tmp'
                },
                { inplace => 0,
                  checksum => 0,
                  progress => 1,
                  verbose => 1,
                  localhost => 'a-lnx005',
                },
            )
        ],
        [   {   'btype'             => 'rsync',
                'stats'             => 1,
                'src'               => '/home/spin/bin/',
                'checksum'          => 0,
                'exclude'           => [],
                'backupdestination' => 'data-tmp',
                'tag'               => 'a-lnx005-home-spin-bin',
                'host'              => 'a-lnx005',
                'inplace'           => 0,
                'gtag'              => 'generic-home-spin-bin',
                'dest'              => '/data/tmp/rsync/a-lnx005-home-spin-bin',
                'path'              => '/home/spin/bin/',
                'progress'          => 1,
                'verbose'           => 1,
                'rdiffbackupbinary' => 'rdiff-backup',
                'duplicitybinary' => 'duplicity',
                'tricklebinary' => 'trickle',
                'zfsbinary' => 'zfs',
                'rsyncbinary' => 'rsync',
            }
        ],
        "cli override inplace and checksum",
    );

    # start of tick-tock
    $EXCLUDE_PATH = './tests';
    is( [   sort { $$a{dest} cmp $$b{dest} } parse_config_backups(
                \%DEFAULT_CONFIG,
                {   'backupset' => {
                        'tick ' => {
                            'host' => 'tick.physics.uiowa.edu',
                            'path' =>
                                [ '/', '/usr', '/var', '/home', '/tmp' ],
                            'inplace'   => 1,
                            'inventory' => 0
                        },
                        'tock' => {
                            'path'      => [ '/', '/home' ],
                            'inplace'   => 1,
                            'inventory' => 0,
                            'host'      => 'tock'
                        }
                    },
                    'backupdestination' =>
                        { 'scratch' => { 'path' => '/scratch/backups' } },
                    'defaultbackupdestination' => 'scratch'
                },
                \%CLI_CONFIG,
            )
        ],
        [   {   'inventory' => 0,
                'path'      => '/home/',
                'exclude'   => [],
                'src'       => 'tick.physics.uiowa.edu:/home/',
                'dest'      => '/scratch/backups/tick.physics.uiowa.edu-home',
                'backupdestination' => 'scratch',
                'btype'             => 'rsync',
                'excludes'          => [
                    'tests/excludes/generic',
                    'tests/excludes/generic-home'
                ],
                'inplace'  => 1,
                'stats'    => 1,
                'host'     => 'tick.physics.uiowa.edu',
                'checksum' => 0,
                'gtag'     => 'generic-home',
                'tag'      => 'tick.physics.uiowa.edu-home',
                'progress' => 0,
                'verbose' => 0,
                'rdiffbackupbinary' => 'rdiff-backup',
                'duplicitybinary' => 'duplicity',
                'tricklebinary' => 'trickle',
                'zfsbinary' => 'zfs',
                'rsyncbinary' => 'rsync',
            },
            {   'dest'      => '/scratch/backups/tick.physics.uiowa.edu-root',
                'inventory' => 0,
                'src'       => 'tick.physics.uiowa.edu:/',
                'exclude'   => [],
                'path'      => '/',
                'stats'     => 1,
                'host'      => 'tick.physics.uiowa.edu',
                'tag'       => 'tick.physics.uiowa.edu-root',
                'checksum'  => 0,
                'gtag'      => 'generic-root',
                'backupdestination' => 'scratch',
                'btype'             => 'rsync',
                'excludes'          => [
                    'tests/excludes/generic',
                    'tests/excludes/generic-root'
                ],
                'inplace' => 1,
                'progress' => 0,
                'verbose' => 0,
                'rdiffbackupbinary' => 'rdiff-backup',
                'duplicitybinary' => 'duplicity',
                'tricklebinary' => 'trickle',
                'zfsbinary' => 'zfs',
                'rsyncbinary' => 'rsync',
            },
            {   'inventory' => 0,
                'exclude'   => [],
                'path'      => '/tmp/',
                'src'       => 'tick.physics.uiowa.edu:/tmp/',
                'dest'      => '/scratch/backups/tick.physics.uiowa.edu-tmp',
                'backupdestination' => 'scratch',
                'btype'             => 'rsync',
                'excludes'          => ['tests/excludes/generic'],
                'inplace'           => 1,
                'stats'             => 1,
                'host'              => 'tick.physics.uiowa.edu',
                'gtag'              => 'generic-tmp',
                'tag'               => 'tick.physics.uiowa.edu-tmp',
                'checksum'          => 0,
                'progress' => 0,
                'verbose' => 0,
                'rdiffbackupbinary' => 'rdiff-backup',
                'duplicitybinary' => 'duplicity',
                'tricklebinary' => 'trickle',
                'zfsbinary' => 'zfs',
                'rsyncbinary' => 'rsync',
            },
            {   'tag'      => 'tick.physics.uiowa.edu-usr',
                'gtag'     => 'generic-usr',
                'checksum' => 0,
                'host'     => 'tick.physics.uiowa.edu',
                'stats'    => 1,
                'inplace'  => 1,
                'excludes' => [
                    'tests/excludes/generic',
                    'tests/excludes/generic-usr'
                ],
                'btype'             => 'rsync',
                'backupdestination' => 'scratch',
                'dest'      => '/scratch/backups/tick.physics.uiowa.edu-usr',
                'exclude'   => [],
                'path'      => '/usr/',
                'src'       => 'tick.physics.uiowa.edu:/usr/',
                'inventory' => 0,
                'progress' => 0,
                'verbose' => 0,
                'rdiffbackupbinary' => 'rdiff-backup',
                'duplicitybinary' => 'duplicity',
                'tricklebinary' => 'trickle',
                'zfsbinary' => 'zfs',
                'rsyncbinary' => 'rsync',
            },
            {   'backupdestination' => 'scratch',
                'btype'             => 'rsync',
                'excludes'          => [
                    'tests/excludes/generic',
                    'tests/excludes/generic-var',
                    'tests/excludes/tick.physics.uiowa.edu-var'
                ],
                'inplace'   => 1,
                'stats'     => 1,
                'host'      => 'tick.physics.uiowa.edu',
                'gtag'      => 'generic-var',
                'checksum'  => 0,
                'tag'       => 'tick.physics.uiowa.edu-var',
                'inventory' => 0,
                'exclude'   => [],
                'path'      => '/var/',
                'src'       => 'tick.physics.uiowa.edu:/var/',
                'dest'      => '/scratch/backups/tick.physics.uiowa.edu-var',
                'progress' => 0,
                'verbose' => 0,
                'rdiffbackupbinary' => 'rdiff-backup',
                'duplicitybinary' => 'duplicity',
                'tricklebinary' => 'trickle',
                'zfsbinary' => 'zfs',
                'rsyncbinary' => 'rsync',
            },
            {   'exclude'   => [],
                'path'      => '/home/',
                'src'       => 'tock:/home/',
                'inventory' => 0,
                'dest'      => '/scratch/backups/tock-home',
                'inplace'   => 1,
                'excludes'  => [
                    'tests/excludes/generic',
                    'tests/excludes/generic-home'
                ],
                'btype'             => 'rsync',
                'backupdestination' => 'scratch',
                'tag'               => 'tock-home',
                'checksum'          => 0,
                'gtag'              => 'generic-home',
                'host'              => 'tock',
                'stats'             => 1,
                'progress' => 0,
                'verbose' => 0,
                'rdiffbackupbinary' => 'rdiff-backup',
                'duplicitybinary' => 'duplicity',
                'tricklebinary' => 'trickle',
                'zfsbinary' => 'zfs',
                'rsyncbinary' => 'rsync',
            },
            {   'exclude'   => [],
                'path'      => '/',
                'src'       => 'tock:/',
                'inventory' => 0,
                'dest'      => '/scratch/backups/tock-root',
                'inplace'   => 1,
                'excludes'  => [
                    'tests/excludes/generic',
                    'tests/excludes/generic-root',
                    'tests/excludes/tock-root'
                ],
                'btype'             => 'rsync',
                'backupdestination' => 'scratch',
                'tag'               => 'tock-root',
                'checksum'          => 0,
                'gtag'              => 'generic-root',
                'host'              => 'tock',
                'stats'             => 1,
                'progress' => 0,
                'verbose' => 0,
                'rdiffbackupbinary' => 'rdiff-backup',
                'duplicitybinary' => 'duplicity',
                'tricklebinary' => 'trickle',
                'zfsbinary' => 'zfs',
                'rsyncbinary' => 'rsync',
            }
        ],
        "tick-tock",
    );
}

done_testing;
