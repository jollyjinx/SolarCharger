#!/usr/bin/perl
use strict;
use FindBin; use lib "$FindBin::Bin/perl5/lib/perl5","$FindBin::Bin/JNX","$FindBin::Bin";

use JNX::Configuration;
use JNX::SMAReader;
use Net::MQTT::Simple;
use JSON::PP;

use JNX::JLog;

my %commandlineoption = JNX::Configuration::newFromDefaults(
                                                                'looptime'      => [ 1,'number'],
                                                                'jsonoutput'    => [ 1,'flag'],
                                                                'mqttserver'    => [ '','string'],
                                                                'mqtttopic'     => [ 'sma/sunnyboy3','string'],
                                                            );

my  $pvReader    = JNX::SMAReader->new() || die "Could not create smareader";
my  $mqtt = undef;

if( $commandlineoption{mqttserver} )
{
    $mqtt = Net::MQTT::Simple->new($commandlineoption{mqttserver});
}

while(1)
{
   # $pvReader->sleepReading($commandlineoption{'looptime'});

    if( $commandlineoption{mqttserver} )
    {
        my $value = $pvReader->loopLineData();

        my $jsonstring = ''.JSON::PP::encode_json($value);
        JNX::JLog::debug "publishing:".$jsonstring;

        $mqtt->publish($commandlineoption{mqtttopic},$jsonstring ); # JSON::PP::encode_json($value) );
    }
    elsif( $commandlineoption{jsonoutput} )
    {
        $pvReader->showLoopLineJSON();
    }
    else
    {
        $pvReader->showLoop($commandlineoption{'looptime'});
        $pvReader->showLoopLine();
    }

    sleep($commandlineoption{'looptime'});
}

