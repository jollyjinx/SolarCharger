#!/usr/bin/perl
use strict;
use utf8;
use open qw( :std :encoding(utf-8) );
binmode STDOUT,':bytes';
binmode STDERR,':bytes';

use POSIX;
use Time::HiRes qw(usleep);
use Data::Dumper;


package JNX::JLog::Level;

use constant {
                fatal  => 0,
                error  => 1,
                warn   => 2,
                info   => 3,
                debug  => 4,
                trace  => 5,
                all    => 6,
            };

use constant names  =>  {
                            JNX::JLog::Level::fatal  => 'fatal',
                            JNX::JLog::Level::error  => 'error',
                            JNX::JLog::Level::warn   => 'warn',
                            JNX::JLog::Level::info   => 'info',
                            JNX::JLog::Level::debug  => 'debug',
                            JNX::JLog::Level::trace  => 'trace',
                            JNX::JLog::Level::all    => 'all',
                        };
             
package JNX::JLog;

my $loglevel        = JNX::JLog::Level::warn;
my $canbechanged    = 1;

{
    select(STDERR);
    $| = 1;

    JNX::JLog::setLevel(JNX::JLog::Level::fatal,1)  if grep( /^\-?\-fatal$/o ,@ARGV);
    JNX::JLog::setLevel(JNX::JLog::Level::error,1)  if grep( /^\-?\-error$/o ,@ARGV);
    JNX::JLog::setLevel(JNX::JLog::Level::warn,1)   if grep( /^\-?\-warn$/o ,@ARGV);
    JNX::JLog::setLevel(JNX::JLog::Level::info,1)   if grep( /^\-?\-info$/o ,@ARGV);
    JNX::JLog::setLevel(JNX::JLog::Level::debug,1)  if grep( /^\-?\-debug$/o ,@ARGV);
    JNX::JLog::setLevel(JNX::JLog::Level::trace,1)  if grep( /^\-?\-trace$/o ,@ARGV);
    JNX::JLog::setLevel(JNX::JLog::Level::all,1)    if grep( /^\-?\-all$/o ,@ARGV);
}


sub setLevel
{
    my($level,$commandlineoption) = @_;

    if( $canbechanged )
    {
        my $levelnames = JNX::JLog::Level::names;
        my %levelnames = %{$levelnames};
        my %inversenames = reverse %levelnames;
        $loglevel = exists( $inversenames{$level} ) ? $inversenames{$level} : $level;
        JNX::JLog::warn( 'loglevel now:'.$loglevel.' ('.$$levelnames{$loglevel}.')'  );
    }
    if( $commandlineoption )
    {
        JNX::JLog::warn("loglevel has been set by commandline option and can't be changed");
        $canbechanged = 0;
    }
}


sub levellog
{
    my($level,@arguments) = @_;

    my($package, $filename, $line1, $subr, $has_args, $wantarray) = caller(2);
    my $line = (caller(1))[2];
    my $now = Time::HiRes::time();

    my $subseconds = substr(sprintf("%.3f",($now-int($now))),1);
    my $timestring = POSIX::strftime('%H:%M:%S', localtime($now)).$subseconds;

    if( @arguments > 0)
    {
        if( my $firstref = ref(@arguments[0]) )
        {
            if(    ('HASH'  eq $firstref)
                || ('ARRAY' eq $firstref)
              )
            {
                print STDERR $timestring.':'.$level.'['.$$.']:'.$package.'::'.$subr.'.'.$line.':'."Dumped:\n".Data::Dumper(@arguments);
                return undef;
            }
        }
        print STDERR $timestring.':'.$level.'['.$$.']:'.$package.'::'.$subr.'.'.$line.':';
        print STDERR @arguments;
        print STDERR "\n";
        return undef;
    }
    print STDERR $timestring.':'.$level.'['.$$.']:'.$package.'::'.$subr.'.'.$line.':'.$subr."()\n";

    return undef;
}

sub log
{
    levellog( 'NONE',@_);
}

sub fatal   { if( $loglevel >= JNX::JLog::Level::fatal ){ levellog('FATAL',@_); } }
sub error   { if( $loglevel >= JNX::JLog::Level::error ){ levellog('ERROR',@_); } }
sub warn    { if( $loglevel >= JNX::JLog::Level::warn  ){ levellog('WARN',@_);  } }
sub info    { if( $loglevel >= JNX::JLog::Level::info  ){ levellog('INFO',@_);  } }
sub debug   { if( $loglevel >= JNX::JLog::Level::debug ){ levellog('DEBUG',@_); } }
sub trace   { if( $loglevel >= JNX::JLog::Level::trace ){ levellog('TRACE',@_); } }


1;
