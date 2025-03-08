#!/usr/bin/perl
use strict;
use utf8;


package JNX::HTTPToUDPServer;
use Errno qw( EINTR );
use POSIX;
use Time::HiRes qw(usleep);
use Data::Dumper;
use IO::Socket::INET;
use Socket qw(SOL_SOCKET SO_RCVBUF IPPROTO_IP IP_TTL);

#use Encode /encode/;

use JNX::JLog;
use JNX::Configuration;
use JNX::JSONHelper;

my %commandlineoption = JNX::Configuration::newFromDefaults(
                                                                'MaximumPacketSize' => [64 * 1024,'number'],
                                                                'LocalAddr'         => ['0.0.0.0','string'],
                                                                'LocalPort'         => [5145,'number'],

                                                                'UDPTimeoutTime'    => [3,'number'],
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

    my %children;

    my $debug=0;
    my  $tcpserversocket = IO::Socket::INET->new( LocalAddr => $self->{LocalAddr}, LocalPort => $self->{LocalPort}, Listen => 5, Reuse => 1)  || die "Cannot create socket: $@";
#        $tcpserversocket->setsockopt(SOL_SOCKET, SO_SNDBUF, $self->{MaximumPacketSize} )  || die "setsockopt: $!";

    $SIG{CHLD} = sub {
        # don't change $! and $? outside handler
        local ($!, $?);
        while ( (my $pid = waitpid(-1, WNOHANG)) > 0 ) {
            delete $children{$pid};
            # cleanup_child($pid, $?);
            JNX::JLog::debug "child died";
        }
        JNX::JLog::debug "child died2";
    };
    $SIG{'HUP'}     = sub { JNX::JLog::error "Sig HUP received"; };
    $SIG{'INT'}     = sub { JNX::JLog::error "Sig INT received";  };
    $SIG{'QUIT'}    = sub { JNX::JLog::error "Sig QUIT received";  };
    $SIG{'ILL'}     = sub { JNX::JLog::error "Sig ILL received";  };
    $SIG{'TRAP'}    = sub { JNX::JLog::error "Sig TRAP received";  };
    $SIG{'ABRT'}    = sub { JNX::JLog::error "Sig ABRT received";  };
    $SIG{'TERM'}    = sub { JNX::JLog::error "Sig TERM received";  };
    $SIG{'IGABRT'}  = sub { JNX::JLog::error "Sig IGABRT received"; };
    $SIG{'SIGABRT'} = sub { JNX::JLog::error "Sig SIGABRT received"; };

    ACCEPTLOOP: while( 1 )
    {
        while( my $client = $tcpserversocket->accept() )
        {
            my $pid = fork();

            if( $pid == 0)  #child
            {
                $tcpserversocket->close; # not needed in child
                $self->httpclient($client);
                exit;
            }
            else
            {
                $children{$pid} = 1;

                $client->close; # not needed in parent
                # wait();
            }
        }

        next ACCEPTLOOP if $! == EINTR;
        JNX::JLog::fatal "could not accept(): $!";
        exit;
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
        JNX::JLog::trace "read: ".Data::Dumper->Dumper(\$body);

        $body = undef if $body eq 'undefined';
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

    my $code = '200 OK';
    my $content = undef;
    my $type = 'text/html';

    if( $$request{command} eq 'GET' && $$request{path} eq '/' )
    {
        $content = `cat "$self->{FileToServe}"`;
    }
    elsif( $$request{command} eq 'GET') #  && $$request{path} eq '/solarcharger.json' )
    {
        $type = 'application/json';
        $content = $self->sendAndReceiveJSONviaUDP( $$request{body} );
    }
    elsif( $$request{command} eq 'POST' )
    {
        $type = 'application/json';
        $content = $self->sendAndReceiveJSONviaUDP( $$request{body} );
    }
    else
    {
        $code = '404 Not Found';
        $content = '<html><head></head><body><h1>Error</h2></body></html>';
    }

    my $return = "HTTP/1.1 $code\r\n";
    $return .= "Server: $self->{ServerName} 1.0\r\n";
    $return .= "Content-Type: $type\r\n";
    $return .= "Content-Length: ".(length($content))."\r\n";
#    $return .= "Connection: close\r\n";
    $return .= "Connection: keep-alive\r\n";
    $return .= "\r\n";
    $return .= $content;
    JNX::JLog::trace "Sending back:\n$return";

    $client->send($return);
#    $client->shutdown();
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
    $socket->autoflush();

    JNX::JLog::trace "Receive buffer is ", $socket->getsockopt(SOL_SOCKET, SO_RCVBUF), " bytes";
    JNX::JLog::trace "IP TTL is ", $socket->getsockopt(IPPROTO_IP, IP_TTL);

    JNX::JLog::trace "JSON: $jsonstring";

    my $sent = $socket->send($jsonstring);
    JNX::JLog::trace "sent: $sent";

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
