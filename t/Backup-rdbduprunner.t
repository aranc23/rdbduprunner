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
    is([Backup::rdbduprunner::verbargs({btype => 'rsync',
                                        verbose => 1,
                                        progress => 1,
                                    })],
       [qw(--progress --verbose)],
       "verbargs contains --verbose");
}

{
    is([Backup::rdbduprunner::verbargs({btype => 'rdiff-backup',
                                        verbosity => 9,
                                    terminalverbosity => 1})],
       [qw(--verbosity 9 --terminal-verbosity 1)],
       "verbargs sets levels for rdiff-backup");
}
{
    is([Backup::rdbduprunner::verbargs({btype => 'duplicity',
                                    verbosity => 9})],
       [qw(--verbosity 9)],
       "verbargs sets levels for duplicity");
}

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

is( [sort(Backup::rdbduprunner::hashref_key_filter_array(
    'stuff',
    qr{^sp},
    {
        'bob' => { stuff => 'fork'},
        'sam' => { stuff => 'spoon'},
        'cat' => { stuff => 'fo'},
    },
    ))],
    [sort(qw(bob cat))],
);

is( Backup::rdbduprunner::hashref_key_array_match(
    {
        'bob' => { other => 'infob', listy => ['left','right'] },
        'sam' => { other => 'infos', listy => ['up','down'] },
        'cat' => { other => 'infoc', listy => ['left','right','up'] },
        'tom' => { other => 'infot', listy => ['left','down'] },
    },
    'listy',
    'right'),
    {
        'bob' => { other => 'infob', listy => ['left','right'] },
        'cat' => { other => 'infoc', listy => ['left','right','up'] },
    },
    "righty");

is( Backup::rdbduprunner::dtruefalse(
    { k => 1 },
    'k'),
    1,
    "dtruefalse: 1");

is( Backup::rdbduprunner::dtruefalse(
    { k => 0 },
    'k'),
    0,
    "dtruefalse: 0");
is( Backup::rdbduprunner::dtruefalse(
    { k => 0 },
    'q'),
    undef,
    "dtruefalse: undef");

done_testing;
