#########################

# Change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;

use Test2::V0;
use Backup::rdbduprunner qw(:all);
use Hash::Merge qw(merge);

use Data::Dumper;

{

    Backup::rdbduprunner::merge_config_definition();
    my $config_validator = Config::Validator->new(%config_definition);
    my $load_opts = { validator => $config_validator, section => 'global' };

    my $configs = Backup::rdbduprunner::load_configs(merge($load_opts, { legacy => ['./tests/legacy/rdbduprunner.rc'] }));
    is( $configs,
           {
               './tests/legacy/rdbduprunner.rc' => {
                   'defaultbackupdestination' => 'rsync',
                   'backupset' => {
                       'a-lnx005.divms.uiowa.edu-profile_backup_client-backupset' => {
                           'skip' => [
                               '/backup',
                               '/var/lib/mysql',
                               '/var/lib/pgsql',
                               '/virtual'
                           ],
                           'postrun' => '/usr/adminbin/deep-check-files $RDBDUPRUNNER_BACKUP_SRC $RDBDUPRUNNER_BACKUP_DEST',
                           'exclude' => [
                               'lib/dnf/yumdb',
                               'cache/yum',
                               'cache/dnf',
                               'cache/fscache',
                               'log',
                               'not_backed_up',
                               'lib/flatpak'
                           ],
                           'inventory' => 1,
                           'disabled' => 0,
                           'host' => 'a-lnx005.divms.uiowa.edu',
                           'skipre' => [
                               '^\\/run\\/media',
                               '^\\/var\\/lib\\/docker\\/devicemapper'
                           ]
                       },
                       'a-lnx009.divms.uiowa.edu-profile_backup_client-backupset' => {
                           'disabled' => 0,
                           'inventory' => 1,
                           'skipre' => [
                               '^\\/run\\/media',
                               '^\\/var\\/lib\\/docker\\/devicemapper'
                           ],
                           'host' => 'a-lnx009.divms.uiowa.edu',
                           'skip' => [
                               '/var/lib/mysql',
                               '/var/lib/pgsql'
                           ]
                       },
                       'a-lnx003.divms.uiowa.edu-profile_backup_client-backupset' => {
                           'skipre' => [
                               '^\\/run\\/media',
                               '^\\/var\\/lib\\/docker\\/devicemapper'
                           ],
                           'host' => 'a-lnx003.divms.uiowa.edu',
                           'inventory' => 1,
                           'skip' => '/vmware'
                       },
                       'a-lnx004.divms.uiowa.edu-profile_backup_client-backupset' => {
                           'skipre' => [
                               '^\\/run\\/media',
                               '^\\/var\\/lib\\/docker\\/devicemapper'
                           ],
                           'host' => 'a-lnx004.divms.uiowa.edu',
                           'inventory' => 1,
                           'skip' => [
                               '/vmware',
                               '/var/lib/mysql',
                               '/var/lib/pgsql',
                               '/local'
                           ]
                       },
                       'a-lnx007.divms.uiowa.edu-profile_backup_client-backupset' => {
                           'host' => 'a-lnx007.divms.uiowa.edu',
                           'skipre' => [
                               '^\\/run\\/media',
                               '^\\/var\\/lib\\/docker\\/devicemapper'
                           ],
                           'inventory' => 1,
                           'disabled' => 0,
                           'skip' => [
                               '/disk1_backup',
                               '/var/lib/mysql',
                               '/var/lib/pgsql'
                           ]
                       },
                       'a-lnx010.divms.uiowa.edu-profile_backup_client-backupset' => {
                           'skip' => [
                               '/sync',
                               '/home/accx/Sync',
                               '/home2',
                               '/var/lib/mysql',
                               '/var/lib/pgsql',
                               '/virtual'
                           ],
                           'inventory' => 1,
                           'exclude' => [
                               'lib/dnf/yumdb',
                               'cache/yum',
                               'cache/dnf',
                               'cache/fscache',
                               'log',
                               'not_backed_up',
                               'lib/flatpak'
                           ],
                           'disabled' => 0,
                           'postrun' => '/usr/adminbin/deep-check-files $RDBDUPRUNNER_BACKUP_SRC $RDBDUPRUNNER_BACKUP_DEST',
                           'skipre' => [
                               '^\\/run\\/media',
                               '^\\/var\\/lib\\/docker\\/devicemapper'
                           ],
                           'host' => 'a-lnx010.divms.uiowa.edu'
                       },
                       'a-lnx006.divms.uiowa.edu-profile_backup_client-backupset' => {
                           'host' => 'a-lnx006.divms.uiowa.edu',
                           'skipre' => [
                               '^\\/run\\/media',
                               '^\\/var\\/lib\\/docker\\/devicemapper'
                           ],
                           'inventory' => 1,
                           'disabled' => 0,
                           'skip' => [
                               '/var/lib/mysql',
                               '/var/lib/pgsql'
                           ]
                       },
                       'a-lnx008.divms.uiowa.edu-profile_backup_client-backupset' => {
                           'host' => 'a-lnx008.divms.uiowa.edu',
                           'skipre' => [
                               '^\\/run\\/media',
                               '^\\/var\\/lib\\/docker\\/devicemapper'
                           ],
                           'exclude' => [
                               'lib/dnf/yumdb',
                               'cache/yum',
                               'cache/dnf',
                               'cache/fscache',
                               'log',
                               'not_backed_up',
                               'lib/flatpak'
                           ],
                           'disabled' => 0,
                           'inventory' => 1,
                           'skip' => [
                               '/var/lib/mysql',
                               '/var/vmware',
                               '/tmp'
                           ]
                       }
                   },
                   'backupdestination' => {
                       'rsync' => {
                           'zfscreate' => 1,
                           'type' => 'rsync',
                           'path' => '/stor01/backups/rsync',
                           'zfssnapshot' => 1
                       }
                   },
                   'allowfs' => [
                       'ext2',
                       'ext3',
                       'ext4',
                       'jfs',
                       'xfs',
                       'reiserfs',
                       'btrfs'
                   ],
                   'zfsbinary' => '/usr/sbin/zfs',
                   'maxprocs' => '4',
                   'wholefile' => 1
               }
           },
       "massive legacy file");
    ok(lives { Backup::rdbduprunner::validate_each($configs) },
       "legacy config is valid");



    $configs = Backup::rdbduprunner::load_configs(merge($load_opts,
                                                        { stems => ['./tests/modern/rdbduprunner'],
                                                          dirs => ['./tests/modern/conf.d'],
                                                      }));
    is($configs,
                  {
                    './tests/modern/rdbduprunner.conf' => {
                                                            'defaultbackupdestination' => 'data-tmp',
                                                            'backupset' => {
                                                                             'test' => {
                                                                                         'path' => '/home/spin/bin'
                                                                                       }
                                                                           },
                                                            'backupdestination' => {
                                                                                     'data-tmp' => {
                                                                                                     'type' => 'rsync',
                                                                                                     'path' => '/data/tmp/rsync'
                                                                                                   }
                                                                                   }
                                                          },
                    'tests/modern/conf.d/backupset.yaml' => { backupset => { stuff => { path => '/etc'} } },
                    './tests/modern/rdbduprunner.json' => {
                                                            'maxwait' => 20000
                                                          },
                    './tests/modern/rdbduprunner.yaml' => {
                                                            'maxprocs' => 9
                                                          },
                    'tests/modern/conf.d/backupdestination.json' => {
                        backupdestination => { bob => { path => '/data/rsync', type => 'rsync'} } },
                },
       "modern tick config with many merges");
    ok(lives { Backup::rdbduprunner::validate_each($configs) },
       "modern config is valid");
    ok(lives { $config_validator->validate(Backup::rdbduprunner::merge_configs($configs),'global') },
       "merged modern config is valid");

    # start of "modern no stems"
    $configs = Backup::rdbduprunner::load_configs(merge($load_opts,
                                                        { stems => ['./tests/modern-no-stems/rdbduprunner'],
                                                          dirs => ['./tests/modern-no-stems/conf.d'],
                                                      }));
    is($configs,
       {
           'tests/modern-no-stems/conf.d/backupset.yaml' => { backupset => { stuff => { path => '/etc'} } },
           'tests/modern-no-stems/conf.d/backupdestination.json' => {
               backupdestination => { bob => { path => '/data/rsync', type => 'rsync'} } },
       },
       "modern no stems");
    ok(lives { Backup::rdbduprunner::validate_each($configs) },
       "modern no stems config is valid");
    ok(lives { $config_validator->validate(Backup::rdbduprunner::merge_configs($configs),'global') },
       "merged no stems modern config is valid");
}

done_testing;
