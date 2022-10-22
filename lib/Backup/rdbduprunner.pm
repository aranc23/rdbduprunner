package Backup::rdbduprunner;

use 5.016003;
use strict;
use warnings;

require Exporter;
use AutoLoader qw(AUTOLOAD);

# used for dispatcher
use Log::Dispatch;
use Log::Dispatch::Syslog;
use Log::Dispatch::Screen;
use Log::Dispatch::File;
use POSIX qw( strftime pause );
use Readonly;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration	use Backup::rdbduprunner ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
create_dispatcher
debug
info
notice
warning
error
critical
alert
emergency
dlog
$EXIT_CODE
&verbargs
$VERBOSITY
$TVERBOSITY
$VERBOSE
$PROGRESS
 ) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw(
	
);

our $VERSION = '1.4.5';

# from the man page for rsync 3.1.1
Readonly our $EXIT_CODE => {
    'rsync' => {
        '0'  => 'Success',
        '1'  => 'Syntax or usage error',
        '2'  => 'Protocol incompatibility',
        '3'  => 'Errors selecting input/output files, dirs',
        '4'  => 'Requested  action  not  supported',
        '5'  => 'Error starting client-server protocol',
        '6'  => 'Daemon unable to append to log-file',
        '10' => 'Error in socket I/O  Error in file I/O',
        '11' => 'Error in file I/O',
        '12' => 'Error in rsync protocol data stream',
        '13' => 'Errors with program diagnostics',
        '14' => 'Error in IPC code',
        '20' => 'Received SIGUSR1 or SIGINT',
        '21' => 'Some error returned by waitpid()',
        '22' => 'Error allocating core memory buffers',
        '23' => 'Partial transfer due to error',
        '24' => 'Partial transfer due to vanished source files',
        '25' => 'The --max-delete limit stopped deletions',
        '30' => 'Timeout in data send/receive',
        '35' => 'Timeout waiting for daemon connection',
    },
};

# dispatcher needs a handle to write to:
our $DISPATCHER;

# these are "global" configuration options that need to move into a
# hash:
our $VERBOSITY;
our $TVERBOSITY;
# rsync specific
our $VERBOSE=0;
our $PROGRESS=0;

=item callback_clean(I have no idea)

I think the point is for remove a new line from the message key in the
hash passed to it.

Used by Log::Dispatch;

=cut
my $callback_clean = sub { my %t=@_;
                           chomp $t{message};
                           return $t{message}."\n"; # add a newline
                         };

=item create_dispatcher($ident, $facility, $log_level, $log_file)

Creates a dispatcher object then attaches the syslog, file, and screen
logging.

=cut
sub create_dispatcher {
    my ( $IDENT, $FACILITY, $LOG_LEVEL, $LOG_FILE ) = @_;
    $DISPATCHER = Log::Dispatch->new( callbacks => $callback_clean );

    $DISPATCHER->add(
        Log::Dispatch::Syslog->new(
            name      => 'syslog',
            min_level => $LOG_LEVEL,
            ident     => $IDENT . '[' . $$ . ']',
            facility  => $FACILITY,
            socket    => 'unix',
        )
    );

    $DISPATCHER->add(
        Log::Dispatch::Screen->new(
            name      => 'screen',
            min_level => $LOG_LEVEL,
            stderr    => 0,
        )
    );
    $DISPATCHER->add(
        Log::Dispatch::File->new(
            name      => 'logfile',
            min_level => $LOG_LEVEL,
            filename  => $LOG_FILE,
            mode      => '>>',
        )
    );
}

sub debug {
  $DISPATCHER->debug(@_);
}
sub info {
  $DISPATCHER->info(@_);
}
sub notice {
  $DISPATCHER->notice(@_);
}
sub warning {
  $DISPATCHER->warning(@_);
}
sub error {
  $DISPATCHER->error(@_);
}
sub critical {
  $DISPATCHER->critical(@_);
}
sub alert {
  $DISPATCHER->alert(@_);
}
sub emergency {
  $DISPATCHER->emergency(@_);
}

sub dlog {
  my $level = shift;
  my $msg   = shift;
  my $time  = time();
  my $str   = stringy({'msg'      => $msg,
                       'severity' => $level,
                       timestamp  => $time,
                       datetime   => POSIX::strftime("%FT%T%z",localtime($time))},
                      @_);
  $DISPATCHER->log( level   => $level,
                    message => $str,
                  );
  return $str;
}

sub stringy {
  # each element passed to stringy should be a HASH REF
  my %a; # strings
  foreach my $h (@_) {
    next unless ref $h eq 'HASH';
    foreach my $key (keys(%$h)) {
      next if ref ${$h}{$key}; # must not be a reference
      my $val=${$h}{$key};
      $val =~ s/\n/NL/g; # remove newlines
      $val =~ s/"/\\"/g; # replace " with \"
      if($key eq 'tag' or $key eq 'host') {
        $a{"rdbduprunner_${key}"}=$val;
      } else {
        $a{$key}=$val;
      }
    }
  }
  my @f;
  foreach my $key (sort {&sort_tags} (keys(%a))) {
    push(@f,"$key=\"$a{$key}\"");
  }
  return join(" ",@f);
}

sub sort_tags {
  return tag_prio($a) <=> tag_prio($b);
}

sub tag_prio {
  my %prios=(
             datetime  => -10,
             severity  => -9,
             msg       => -5,
             timestamp => 50,
             host      => 2,
             tag       => 1,
             backupdestination => 10,
             dest      => 10,
             gtag      => 10,
             btype     => 10,
            );
  my $t=lc $_[0];
  return $prios{$t} if defined $prios{$t};
  return 0;
}

sub verbargs {
  my $bh=$_[0];
  my @a;
  if($$bh{btype} ne 'rsync') {
    if(defined $VERBOSITY) {
      push(@a,'--verbosity',$VERBOSITY);
    }
    if(defined $TVERBOSITY and $$bh{btype} eq 'rdiff-backup') {
      push(@a,'--terminal-verbosity',$TVERBOSITY);
    }
  }
  else {
    if($PROGRESS) {
      push(@a,'--progress');
    }
    if($VERBOSE) {
      push(@a,'--verbose');
    }
  }
  return(@a);
}

# Preloaded methods go here.

# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Backup::rdbduprunner - Perl extension for blah blah blah

=head1 SYNOPSIS

  use Backup::rdbduprunner;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for Backup::rdbduprunner, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

Aran Cox, E<lt>arancox@gmail.com<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2022 by Aran Cox

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.34.1 or,
at your option, any later version of Perl 5 you may have available.


=cut
