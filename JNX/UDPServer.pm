#!/usr/bin/perl
use strict;
use utf8;

use JNX::JLog;

package JNX::UDPServer;

use POSIX;
use Time::HiRes qw(usleep);
use Data::Dumper;
use IO::Socket::INET;
use Socket qw(SOL_SOCKET SO_RCVBUF IPPROTO_IP IP_TTL);
use JSON::PP;
use JNX::Configuration;

my %commandlineoption = JNX::Configuration::newFromDefaults(
                                                                'MaximumPacketSize' => [64 * 1024,'number'],
                                                                'LoopTime'          => [5,'number'],
                                                                'LocalPort'         => [5145,'number'],
                                                                'LocalAddr'         => ['0.0.0.0','string'],
                                                            );

sub new
{
    my ($class,%options) = (@_);

    JNX::JLog::trace;

    my $self = {};
    bless $self, $class;

    $self->{debug}                  = $options{debug}             ||  $commandlineoption{'debug'};
    $self->{MaximumPacketSize}      = $options{MaximumPacketSize} || $commandlineoption{'MaximumPacketSize'};
    $self->{LoopTime}               = $options{LoopTime}          || $commandlineoption{'LoopTime'};
    $self->{LocalPort}              = $options{LocalPort}         || $commandlineoption{'LocalPort'};
    $self->{LocalAddr}              = $options{LocalAddr}         || $commandlineoption{'LocalAddr'};
    $self->{Worker}                 = $options{Worker}            || Carp::croak "Missing Worker";

    $self->{'socket'} = $self->setup();

    return $self;
}

sub setup
{
    my ($self,%options) = (@_);

    JNX::JLog::trace;

    my  $socket = IO::Socket::INET->new( LocalAddr => $self->{LocalAddr} , LocalPort => $self->{LocalPort}, Proto => 'udp')  || die "Cannot create socket: $@";

        $socket->setsockopt(SOL_SOCKET, SO_RCVBUF, $self->{MaximumPacketSize})  || die "setsockopt: $!";

    my $innerlooptime = $self->{LoopTime} / 3;
    my $seconds  = int($innerlooptime);
    my $useconds = int( 1_000_000 * ( $innerlooptime - $seconds ) );
    my $timeout  = pack( 'l!l!', $seconds, $useconds );

        $socket->setsockopt(SOL_SOCKET, SO_RCVTIMEO, $timeout)      || die "setsockopt: $!";

    JNX::JLog::trace "Receive buffer is ", $socket->getsockopt(SOL_SOCKET, SO_RCVBUF), " bytes";
    JNX::JLog::trace "IP TTL is ", $socket->getsockopt(IPPROTO_IP, IP_TTL);

    return $socket;
}

sub run
{
    my ($self,%options) = (@_);

    JNX::JLog::trace;

    my $socket = $self->{'socket'};
    my $nextruntime = 0;

    while(1)
    {
        my $now = time();

        if( $now > $nextruntime )
        {
            JNX::JLog::trace "looptime";
            $self->{Worker}->workloop();
            $nextruntime = $now + $self->{LoopTime};
        }

        if( $socket->recv(my $newmessage,$self->{MaximumPacketSize}) )
        {
            JNX::JLog::trace $newmessage;
            $self->receivedCommand($socket,$newmessage);
        }
        else
        {
            JNX::JLog::trace "timeout recv";   # normal for workloop to timeout
        }
    }
}


sub receivedCommand
{
    my($self,$socket,$message) = @_;

    JNX::JLog::trace;

    my $command         = eval { JSON::PP->new->utf8(1)->decode( $message ) };
    my $returncommand   = $self->{Worker}->command($command);
    my $returnjson      = JSON::PP->new->utf8(1)->encode( $returncommand );

    JNX::JLog::trace "returning: $returnjson";
    $socket->send($returnjson);
}

1;
