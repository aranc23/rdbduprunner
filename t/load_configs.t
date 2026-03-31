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




is([sort(find_configs(['./tests/modern/conf.d'],['./tests/modern/rdbduprunner']))],
        [sort('tests/modern/conf.d/backupset.yaml',
              './tests/modern/rdbduprunner.json',
              './tests/modern/rdbduprunner.yaml',
              'tests/modern/conf.d/backupdestination.json')],
        "find dirs and stems");

$configs = Backup::rdbduprunner::load_configs(find_configs(['./tests/modern/conf.d'],['./tests/modern/rdbduprunner']));
    is($configs,
                   {
                     'tests/modern/conf.d/backupset.yaml' => {
                         'zfssnapshot' => 'true',
                         'zfscreate' => 'false',
                         backupset => {
                             stuff => { path => '/etc', 'wholefile' => 'false'} } },
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
    ok([sort(find_configs( ['./tests/modern-no-stems/conf.d'], ['./tests/modern-no-stems/rdbduprunner'] ))],
       [sort('tests/modern-no-stems/conf.d/backupset.yaml', 'tests/modern-no-stems/conf.d/backupdestination.json')],
       "find_configs modern no stems");

    $configs = Backup::rdbduprunner::load_configs(find_configs( ['./tests/modern-no-stems/conf.d'], ['./tests/modern-no-stems/rdbduprunner'] ));
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
