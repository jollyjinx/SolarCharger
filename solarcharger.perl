#!/usr/bin/perl
use strict;
use FindBin; use lib "$FindBin::Bin/perl5/lib/perl5","$FindBin::Bin","$FindBin::Bin/JNX";
use utf8;
use English;

use JNX::JLog;
use JNX::UDPServer;
use JNX::HTTPToUDPServer;
use JNX::SolarWorker;
use JNX::Configuration;

my %commandlineoption = JNX::Configuration::newFromDefaults(
                                                                'localaddress'  => [ '0.0.0.0','string'],
                                                                'localport'     => [5145,'number'],
                                                                'cars'          => ['','string'],
                                                                'basecarurl'    => ['','string'],
                                                            );
{
    my $localaddress        = $commandlineoption{'localaddress'};
    my $serverport          = $commandlineoption{'localport'};

    my $fatherprocess = $$;
    my %children;

    sub killchildren {
                            my @childprocesses = keys %children;
                            JNX::JLog::fatal "$$ children died ",join(',',@childprocesses).'args:'.join(',', @_);
                            kill('KILL',@childprocesses) if @childprocesses > 0;
                            exit;
                      };

    $SIG{CHLD} = sub {
        # don't change $! and $? outside handler
        local ($!, $?);
        while ( (my $pid = waitpid(-1, WNOHANG)) > 0 )
        {
            if( defined $children{$pid} )
            {
                JNX::JLog::fatal "known child died - killing everything";
                killchildren();
            }
            else
            {
                JNX::JLog::error "unknown child died doing nothing.";
            }
        }
    };


    $SIG{'HUP'}     = sub { JNX::JLog::error "Sig HUP received"; killchildren(); };
    $SIG{'INT'}     = sub { JNX::JLog::error "Sig INT received"; killchildren(); };
    $SIG{'QUIT'}    = sub { JNX::JLog::error "Sig QUIT received"; killchildren(); };
    $SIG{'ILL'}     = sub { JNX::JLog::error "Sig ILL received"; killchildren(); };
    $SIG{'TRAP'}    = sub { JNX::JLog::error "Sig TRAP received"; killchildren(); };
    $SIG{'ABRT'}    = sub { JNX::JLog::error "Sig ABRT received"; killchildren(); };
    $SIG{'TERM'}    = sub { JNX::JLog::error "Sig TERM received"; killchildren(); };
    $SIG{'IGABRT'}  = sub { JNX::JLog::error "Sig IGABRT received"; killchildren(); };
    $SIG{'SIGABRT'} = sub { JNX::JLog::error "Sig SIGABRT received"; killchildren(); };


   if( my $childid = createChildProcess('JNX::UDPServer',\&runUDPServer,$localaddress,$serverport) ) {  $children{$childid}=1; }
   if( my $childid = createChildProcess('TCPServer',\&runTCPServer,$localaddress,$serverport) ) {  $children{$childid}=1; }

    JNX::JLog::trace "Father: waiting for children to exit";

    my $child = wait();
    JNX::JLog::trace "Father: child died $child";
    exit;
}
exit;

sub createChildProcess
{
    my($processname,$subroutine,@args) = @_;
    JNX::JLog::trace "Creating child: $processname $subroutine";

    if( my $childprocessid = fork() )
    {
        JNX::JLog::trace "$processname father $$ $childprocessid";
        return $childprocessid;
    }
    JNX::JLog::trace "$processname child $$";

    $SIG{'CHLD'} = sub { wait(); };
    $PROGRAM_NAME = $PROGRAM_NAME.' '.$processname;

    $subroutine->(@args);
    exit;
}


sub runUDPServer
{
    my($localaddress,$serverport) = @_;

    JNX::JLog::trace();

    my @carConnectors;

    for my $carname (split(/,/,$commandlineoption{'cars'}))
    {
        my $carurl = $commandlineoption{'basecarurl'}.$carname.'.json';

        JNX::JLog::debug("creating carconnector: $carurl");
        my $carConnector    = JNX::BMWConnector->new( url => $carurl )      || die "Could not create BMWConnector $carname";
        JNX::JLog::debug("Created carConnector: ".$carConnector->{url});
        push(@carConnectors,$carConnector);
    }

    my $evCharger       = JNX::PhoenixCharger->new()    || die "Could not create PhoenixCharger";
    my $pvReader        = JNX::SMAReader->new()         || die "Could not create SMAReader";

    my $solarworker = JNX::SolarWorker->new(    JNX::SolarWorker::Options::pvReader      => $pvReader,
                                                JNX::SolarWorker::Options::evCharger     => $evCharger,
                                                JNX::SolarWorker::Options::carConnectors => \@carConnectors,
                                            )                                                                           || die "Could not create JNX::SolarWorker";
    my $udpserver   = JNX::UDPServer->new( LocalAddr => $localaddress ,LocalPort => $serverport ,Worker => $solarworker);
    $udpserver->run();
}


sub runTCPServer
{
    my($localaddress,$serverport) = @_;
    JNX::JLog::trace();

    my $httpToJNXUDPServer = JNX::HTTPToUDPServer->new( LocalAddr => $localaddress ,LocalPort => $serverport  );

    $httpToJNXUDPServer->run();
    exit;
}

