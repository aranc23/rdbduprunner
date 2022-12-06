# Before 'make install' is performed this script should be runnable with
# 'make test'. After 'make install' it should work as 'perl Backup-rdbduprunner.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;

use Test2::V0;
use Backup::rdbduprunner qw(:all);

use Data::Dumper;
use Hash::Merge qw(merge);

{
    is( Backup::rdbduprunner::load_config_conf('./tests/tick.conf'),
        {
            backupdestination => {
                scratch => { path => '/scratch/backups' }
            },
            backupset => {
                'tick ' => {
                    host => 'tick.physics.uiowa.edu',
                    inventory => 0,
                    path => [qw(/ /usr /var /home /tmp)],
                },
                tock => {
                    host => 'tock',
                    inventory => 0,
                    path => [sort(qw(/ /home))],
                },
            },
            defaultbackupdestination => 'scratch',
        },
        "tick config file");
    is( Backup::rdbduprunner::load_config_conf('./tests/empty.conf'),
        {},
        "empty file should just return {}");

    is( Backup::rdbduprunner::load_config_conf('./tests/broken.conf'),
        {'<<fork' => {'f' => {'test' => 'val'}}},
        "this should not parse, imho but whatever");

}

done_testing;
