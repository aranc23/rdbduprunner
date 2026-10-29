# Before 'make install' is performed this script should be runnable with
# 'make test'. After 'make install' it should work with 'perl Backup-rdbduprunner.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use strict;
use warnings;

use Test2::V0;
use Backup::rdbduprunner qw(%CONFIG %CLI_CONFIG %DEFAULT_CONFIG);
use File::Temp qw(tempdir);
use File::Spec;

# fake ssh which records its arguments and returns a fixed
# /proc/mounts format listing:
my $tmpdir = tempdir(CLEANUP => 1);
my $fakebin = File::Spec->catdir($tmpdir, 'bin');
my $arglog  = File::Spec->catfile($tmpdir, 'ssh-args');
mkdir($fakebin);
open(my $sh, '>', File::Spec->catfile($fakebin, 'ssh'))
    or die "cannot write fake ssh: $!";
print $sh <<"EOT";
#!/bin/sh
printf '%s\\n' "\$*" > $arglog
printf '%s\\n' "/dev/sda1 / ext4 rw,relatime 0 0" "/dev/sdb1 /home xfs rw,relatime 0 0"
EOT
close($sh);
chmod(0755, File::Spec->catfile($fakebin, 'ssh'));

sub slurp {
    open(my $fh, '<', $_[0]) or die "cannot read $_[0]: $!";
    local $/;
    my $s = <$fh>;
    close($fh);
    $s =~ s/\n\z//;
    return $s;
}

{
    local $ENV{PATH} = File::Spec->catfile($fakebin) . ':' . $ENV{PATH};
    local *Backup::rdbduprunner::info  = sub {};
    local *Backup::rdbduprunner::debug = sub {};
    local *Backup::rdbduprunner::dlog  = sub {};
    local *Backup::rdbduprunner::error = sub { die "inventory failed: $_[0]\n" };

    my @paths;

    # no remoteuser at any layer: plain host
    %CONFIG     = ( 'backupdestination' => { 'scratch' => { 'path' => '/scratch' } } );
    %CLI_CONFIG = ();
    @paths = Backup::rdbduprunner::inventory_host('scratch', { 'host' => 'tock', 'path' => '/etc' });
    is([@paths], [ '/', '/home' ], "inventory paths");
    is(slurp($arglog), '-x -o BatchMode=yes tock cat /proc/mounts', 'no remoteuser: plain host');

    # backupset level remoteuser
    @paths = Backup::rdbduprunner::inventory_host('scratch', { 'host' => 'tock', 'path' => '/etc', 'remoteuser' => 'backup' });
    is(slurp($arglog), '-x -o BatchMode=yes backup@tock cat /proc/mounts', 'backupset remoteuser');

    # global level remoteuser
    %CONFIG = (
        'backupdestination' => { 'scratch' => { 'path' => '/scratch' } },
        'remoteuser'        => 'backup',
    );
    @paths = Backup::rdbduprunner::inventory_host('scratch', { 'host' => 'tock', 'path' => '/etc' });
    is(slurp($arglog), '-x -o BatchMode=yes backup@tock cat /proc/mounts', 'global remoteuser');

    # cli level remoteuser wins over global and backupset
    %CLI_CONFIG = ( 'remoteuser' => 'clipper' );
    @paths = Backup::rdbduprunner::inventory_host('scratch', { 'host' => 'tock', 'path' => '/etc', 'remoteuser' => 'bsuser' });
    is(slurp($arglog), '-x -o BatchMode=yes clipper@tock cat /proc/mounts', 'cli remoteuser wins');

    # local inventory (no host) needs no ssh at all
    unlink($arglog);
    %CONFIG    = ( 'backupdestination' => { 'scratch' => { 'path' => '/scratch' } } );
    %CLI_CONFIG = ();
    @paths = Backup::rdbduprunner::inventory_host('scratch', { 'path' => '/etc' });
    ok(@paths > 0, "local inventory found paths (" . scalar(@paths) . ")");
    ok(!-e $arglog, 'local inventory did not invoke ssh');
}

done_testing;
