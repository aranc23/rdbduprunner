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

sub big_globals {
    return {
        dryrun                  => $DRYRUN,
        'dest'                  => $DEST,
        'host'                  => $HOST,
        'path'                  => $PATH,
    };
}
my $defaults = {
    dryrun                  => 0,
    'dest'                  => undef,
    'host'                  => undef,
    'path'                  => undef,
};

{
    for my $section (qw(cli global backupdestination backupset)) {
        $config_definition{$section}{fields} = merge(
            $config_definition{$section}{fields},
            hashref_keys_drop(
                hashref_key_array_match(\%DEFAULT_CONFIG,
                                        'sections',
                                        $section),
                'default',
                'getopt',
                'sections')
        );
    }

    my $cv = Config::Validator->new(%config_definition);
    my @options = hashref_key_array(\%DEFAULT_CONFIG,
                                    'getopt');
    my $results;
    $results = parse_argv([], \%get_options,@options);
    ok(lives { $cv->validate($results, 'cli'); }, 'unparaseable');
    is( $results,
        {},
        "nothing passed");
    is( big_globals(),
        $defaults,
        "no options global vars",
    );

    $results = parse_argv([qw(--notest --stats)], \%get_options,@options);
    ok(lives { $cv->validate($results, 'cli'); }, 'unparaseable');
    is( $results,
        {stats => 1, test => 0},
        "options: notest and stats");
    is( big_globals(),
        $defaults,
        "old options: notest and stats");

    # start of "everything"
    $results = parse_argv([
        qw(
              --calculate-average
              --cleanup
              --check
              --compare
              --verify
              --dump
              --list-oldest
              --remove-oldest
              --status
              --tidy
              --list
              --orphans
              --status-json
              --status-delete pork
              --force
              --full
              --maxage 1D1W2Y4s
              --maxinc 4
              --verbosity 5
              -t 5
              -u
              --allow-source-mismatch
              --tempdir /var/tmp
              -v
              --progress
              --dry-run
              --wholefile
              --checksum
              --maxprocs 2
              --facility daemon
              --level debug
              --maxwait 32000
              --no-test
      )], \%get_options,@options);
    ok(lives {
        $cv->validate($results,"cli");
    }, "unparaseable");
    is( $results,
        {wholefile => 1,
         checksum => 1,
         terminalverbosity => 5,
         verbosity => 5,
         progress => 1,
         verbose => 1,
         maxprocs => 2,
         facility => 'daemon',
         level => 'debug',
         force => 1,
         full => 1,
         'calculate-average' => 1,
         cleanup => 1,
         compare => 1,
         dump => 1,
         listoldest => 1,
         remove => 1,
         status => 1,
         list => 1,
         orphans => 1,
         status_delete => ['pork'],
         status_json => 1,
         tidy => 1,
         maxwait => 32000,
         maxinc => 4,
         maxage => '1D1W2Y4s',
         useagent => 1,
         allowsourcemismatch => 1,
         test => 0,
         tempdir => '/var/tmp',
     },
        "nothing passed");

    for(qw(dryrun)) {
        $$defaults{$_} = 1;
    }

    is( big_globals(),
        $defaults,
        "everything");

}

done_testing;
