#!/usr/bin/perl
use strict;
use FindBin; use lib "$FindBin::Bin/perl5/lib/perl5","$FindBin::Bin/JNX";
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
                                                            );
{
    my $localaddress        = $commandlineoption{'localaddress'};
    my $serverport          = $commandlineoption{'localport'};

    my $fatherprocess = $$;
    my @childprocesses;

    sub killchildren {
                            JNX::JLog::fatal "$$ children died ",join(',',@childprocesses).'args:'.join(',', @_);

                            kill('KILL',@childprocesses) if @childprocesses > 0;
                            exit;
                      };
    $SIG{'CHLD'}    = \&killchildren;
    $SIG{'HUP'}     = \&killchildren;
    $SIG{'INT'}     = \&killchildren;
    $SIG{'QUIT'}    = \&killchildren;
    $SIG{'ILL'}     = \&killchildren;
    $SIG{'TRAP'}    = \&killchildren;
    $SIG{'ABRT'}    = \&killchildren;
    $SIG{'TERM'}    = \&killchildren;
    $SIG{'IGABRT'}  = \&killchildren;
    $SIG{'SIGABRT'} = \&killchildren;


   if( my $childid = createChildProcess('JNX::UDPServer',\&runJNX::UDPServer,$localaddress,$serverport) ) {  push(@childprocesses,$childid); }
   if( my $childid = createChildProcess('TCPServer',\&runTCPServer,$localaddress,$serverport) ) {  push(@childprocesses,$childid); }

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


sub runJNX::UDPServer
{
    my($localaddress,$serverport) = @_;

    JNX::JLog::trace();

    my $pvReader        = JNX::SMAReader->new()         || die "Could not create SMAReader";
    my $evCharger       = JNX::PhoenixCharger->new()    || die "Could not create PhoenixCharger";
    my $carConnector    = JNX::BMWConnector->new()      || die "Could not create BMWConnector";

    my $solarworker = JNX::SolarWorker->new(    JNX::SolarWorker::Options::pvReader      => $pvReader,
                                                JNX::SolarWorker::Options::evCharger     => $evCharger,
                                                JNX::SolarWorker::Options::carConnector  => $carConnector,
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

