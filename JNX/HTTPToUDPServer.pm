#!/usr/bin/perl
use strict;
use utf8;


package JNX::HTTPToUDPServer;

use POSIX;
use Time::HiRes qw(usleep);
use Data::Dumper;
use IO::Socket::INET;
use Socket qw(SOL_SOCKET SO_RCVBUF IPPROTO_IP IP_TTL);
use JSON::PP;

use JNX::JLog;
use JNX::Configuration;


my %commandlineoption = JNX::Configuration::newFromDefaults(
                                                                'MaximumPacketSize' => [64 * 1024,'number'],
                                                                'LocalAddr'         => ['0.0.0.0','string'],
                                                                'LocalPort'         => [5145,'number'],

                                                                'UDPTimeoutTime'    => [2,'number'],
                                                                'ServerName'        => ['Jollys Simple Solar Charger','string'],
                                                                'FileToServe'       => ['solarcharger.html','string'],
                                                            );

sub new
{
    my ($class,%options) = (@_);

    JNX::JLog::trace;

    my $self = {};
    bless $self, $class;

    $self->{debug}                  = $options{debug}               || $commandlineoption{'debug'};

    $self->{MaximumPacketSize}      = $options{MaximumPacketSize}   || $commandlineoption{'MaximumPacketSize'};
    $self->{LocalAddr}              = $options{LocalAddr}           || $commandlineoption{'LocalAddr'};
    $self->{LocalPort}              = $options{LocalPort}           || $commandlineoption{'LocalPort'};

    $self->{UDPTimeoutTime}         = $options{UDPTimeoutTime}      || $commandlineoption{'UDPTimeoutTime'};
    $self->{ServerName}             = $options{ServerName}          || $commandlineoption{'ServerName'};
    $self->{FileToServe}            = $options{FileToServe}         || $commandlineoption{'FileToServe'};

    return $self;
}



sub run
{
    my($self) = @_;
    JNX::JLog::trace();

    my $debug=0;
    my  $tcpserversocket = IO::Socket::INET->new( LocalAddr => $self->{LocalAddr}, LocalPort => $self->{LocalPort}, Listen => 5, Reuse => 1)  || die "Cannot create socket: $@";

    while( my $client = $tcpserversocket->accept() )
    {
        if( fork() == 0)  #child
        {
            $tcpserversocket->close; # not needed in child
            $self->httpclient($client);
        }
        else
        {
            $client->close; # not needed in parent
            wait();
        }
    }
    exit;
}


sub httpclient
{
    my($self,$client) = @_;

    binmode $client;
    while( my $request = $self->readhttpcommand($client) )
    {
        $self->workoncommand($client,$request);
        last;
    }
    $client ->close;
}



sub readhttpcommand
{
    my($self,$client) = @_;

    JNX::JLog::trace;

    my %request;

    my $commandline = <$client>;
    chomp $commandline;

    if( $commandline =~ m/(POST|GET)\s+(\/\S*)\s+(HTTP\/\d+\.\d+)/o )
    {
        $request{command}       = $1;
        $request{path}          = $2;
        $request{httpversion}   = $3;
    }
    else
    {
        JNX::JLog::error "incorrect command: $commandline";
        return undef;
    }

    HEADER: while( my $headerline  = <$client> )
    {
        if( "\r\n" eq $headerline )
        {
            JNX::JLog::trace "end of header";
            last HEADER;
        }

        if( $headerline =~ m/^([^:]+): (.*?)[\r\n]+$/o )
        {
            $request{header}{$1} = $2;
            JNX::JLog::trace "header: $1 -> $2";
        }
    }

    my $contentlength = $request{header}{'Content-Length'};

    if( $contentlength > 0 )
    {
        my $readlength = read($client,my $body,$contentlength);

        if( $readlength != $contentlength )
        {
            JNX::JLog::error "contentlength should be $contentlength != $readlength";
            return undef;
        }

        $request{body} = $body;
    }
    else
    {
        $request{body} = '';
    }
    JNX::JLog::trace "got request: ".Data::Dumper->Dumper(\%request);

    return \%request;
}



sub workoncommand
{
    my($self,$client,$request) = @_;

    if( $$request{command} eq 'GET' && $$request{path} eq '/' )
    {
        my $content = `cat "$self->{FileToServe}"`;

        print $client "HTTP/1.1 200 OK\n";
        print $client "Server: $self->{ServerName} 1.0\n";
        print $client "Content-Type: text/html\n";
        print $client "Connection: keep-alive\n";
        print $client "Content-Length: ".length($content)."\n";
        print $client "\r\n";
        print $client $content;
    }
    elsif( $$request{command} eq 'POST' )
    {
        my $content = $self->sendAndReceiveJSONviaUDP( $$request{body} );

        print $client "HTTP/1.1 200 OK\n";
        print $client "Server: $self->{ServerName} 1.0\n";
        print $client "Content-Type: application/json\n";
        print $client "Connection: keep-alive\n";
        print $client "Content-Length: ".length($content)."\n";
        print $client "\r\n";
        print $client $content;
    }
    else
    {
        print $client "HTTP/1.1 404 Not Found\n";
        print $client "Server: $self->{ServerName} 1.0\n";
        print $client "Content-Type: text/html\n";
        print $client "Connection: close\n";
        print $client "\r\n";
        print $client "<html><head></head><body><h1>Error</h2></body></html>";
    }
    return 1;
}




sub sendAndReceiveJSONviaUDP
{
    my($self,$jsonstring) = @_;

    JNX::JLog::trace;

    my  $socket = IO::Socket::INET->new(PeerHost => $self->{LocalAddr}, PeerPort => $self->{LocalPort}, Proto => 'udp')  || die "Cannot create socket: $@";
        $socket->setsockopt(SOL_SOCKET, SO_RCVBUF, $self->{MaximumPacketSize} )  || die "setsockopt: $!";

    my $innerlooptime = $self->{UDPTimeoutTime};
    my $seconds  = int($innerlooptime);
    my $useconds = int( 1_000_000 * ( $innerlooptime - $seconds ) );
    my $timeout  = pack( 'l!l!', $seconds, $useconds );

        $socket->setsockopt(SOL_SOCKET, SO_RCVTIMEO, $timeout)      || die "setsockopt: $!";

    JNX::JLog::trace "Receive buffer is ", $socket->getsockopt(SOL_SOCKET, SO_RCVBUF), " bytes";
    JNX::JLog::trace "IP TTL is ", $socket->getsockopt(IPPROTO_IP, IP_TTL);

    JNX::JLog::trace "JSON: $jsonstring";

    $socket->send($jsonstring) or die "send: $!";

    my $returnstring = undef;

    if( $socket->recv(my $newmsg,$self->{MaximumPacketSize} ) )
    {
        JNX::JLog::trace "received: ".$newmsg;

        $returnstring =  $newmsg; # eval { JSON::PP->new->utf8(1)->decode($newmsg) };
        JNX::JLog::debug "received json:\n".Data::Dumper->Dumper($returnstring);
    }
    else
    {
        JNX::JLog::error "timeout recv";
    }
    return $returnstring;
}

1;
