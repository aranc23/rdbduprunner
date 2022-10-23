# Before 'make install' is performed this script should be runnable with
# 'make test'. After 'make install' it should work as 'perl Backup-rdbduprunner.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;

use Test2::V0;
use Backup::rdbduprunner ':all';


#BEGIN { ok('use Backup::rdbduprunner') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

is([Backup::rdbduprunner::verbargs({btype => 'rsync'})],
   [],
   "empty");

{
    $VERBOSE=1;
    $PROGRESS=1;
    is([Backup::rdbduprunner::verbargs({btype => 'rsync'})],
       [qw(--progress --verbose)],
       "verbargs contains --verbose");
}

{
    $VERBOSE=0;
    $PROGRESS=0;
    $VERBOSITY=9;
    $TVERBOSITY=1;
    is([Backup::rdbduprunner::verbargs({btype => 'rdiff-backup'})],
       [qw(--verbosity 9 --terminal-verbosity 1)],
       "verbargs sets levels for rdiff-backup");
}
{
    $VERBOSE=0;
    $PROGRESS=0;
    $VERBOSITY=9;
    $TVERBOSITY=1;
    is([Backup::rdbduprunner::verbargs({btype => 'duplicity'})],
       [qw(--verbosity 9)],
       "verbargs sets levels for duplicity");
}
ok($VERBOSE == 0, "verbose check");

is( {   Backup::rdbduprunner::hash_backups(
    { host => 'test' },
    { host => 'test', param => 1 },
    { host => 'other' })
    },
    {   'test'  => [ { host => 'test' }, { host => 'test', param => 1 } ],
        'other' => [ { host => 'other' } ],
    },
    "hash_backups"
);

done_testing;
