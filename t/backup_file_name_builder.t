# ;; -*- mode: CPerl; -*-
# Before 'make install' is performed this script should be runnable with
# 'make test'. After 'make install' it should work as 'perl Backup-rdbduprunner.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;

use Test2::V0;
use Backup::rdbduprunner qw(&backup_file_name_builder);


{
    is( backup_file_name_builder('mom', 'dad', 'doodle',['sql','gz']),
        'mom-dad-doodle.sql.gz',
        "glues everything together with suffixes",
    );
    is( backup_file_name_builder('mom', 'dad', 'doodle'),
        'mom-dad-doodle',
        "glues everything together without suffixes",
    );
}

done_testing;
