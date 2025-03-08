#!/usr/bin/perl

use strict;
use Carp;

package JNX::CarConnector;
use JNX::JLog;
use JNX::Configuration;
use JNX::JSONHelper;

my %commandlineoption = JNX::Configuration::newFromDefaults(
                                                                'url'               => ['https://example.com/evcharger/car.json','string'],
                                                                'username'          => ['','string'],
                                                                'password'          => ['','string'],

                                                                'chargelimit'       => [70,'number'],
                                                                'pvchargelimit'     => [90,'number'],

                                                                'cachetime'         => [(5 * 60),'number'],
                                                                'outdatedtime'      => [(20 * 60),'number'],
                                                           );

sub new
{
    my ($class,%options) = (@_);

    my $self = {};

    $self->{debug}          = $options{debug}           || $commandlineoption{'debug'};

    $self->{url}            = $options{url}             || $commandlineoption{'url'};
    $self->{username}       = $options{username}        || $commandlineoption{'username'};
    $self->{password}       = $options{password}        || $commandlineoption{'password'};

    $self->{chargelimit}    = $options{chargelimit}     || $commandlineoption{'chargelimit'};
    $self->{pvchargelimit}  = $options{pvchargelimit}   || $commandlineoption{'pvchargelimit'};

    $self->{cachetime}      = $options{cachetime}       || $commandlineoption{'cachetime'};

    JNX::JLog::trace("initalized:".Data::Dumper->Dumper($self));

    bless $self, $class;
    return $self;
}


sub carName                 {   return @_[0]->getVariableFromKeyPath('name') || "unknown"; }
sub isConnected             {   return @_[0]->getVariableFromKeyPath('isConnected') ? 1 : 0 ; }
sub isCharging              {   return @_[0]->getVariableFromKeyPath('isCharging') ? 1 : 0 ; }
sub currentStateOfCharge    {   return @_[0]->getVariableFromKeyPath('soc') + 0.0;     }

sub hasReachedChargeLimitAtHome { return @_[0]->currentStateOfCharge() >= @_[0]->{chargelimit} ? 1 : 0; }
sub hasReachedPVLimitAtHome     { return @_[0]->currentStateOfCharge() >= @_[0]->{pvchargelimit} ? 1 : 0; }



sub getVariableFromKeyPath
{
    my($self,$keypath) = @_;
    JNX::JLog::debug 'keypath:'.$keypath;

    $self->updateDataIfNeeded();

    if(  exists $self->{jsonhash}{$keypath} )
    {
        my $value =  $self->{jsonhash}{$keypath};

        JNX::JLog::trace 'key:'.$keypath.' value:'.$value;
        return $value;
    }
    else
    {
        JNX::JLog::trace 'key:'.$keypath.' no key';
    }

    my $path = '{'.$keypath.'}';
    $path =~ s/\./}{/g;
    my $value = undef;
    my $evaluating = '$value = $self->{jsonhash}'.$path;
    JNX::JLog::trace 'evaluating:'.$evaluating;
    eval "$evaluating";

    JNX::JLog::trace 'key:'.$keypath.' value:'.$value;
    $self->{jsonhash}{$keypath} = $value;
    return $value;
}

sub updateDataIfNeeded
{
    my($self) = @_;
    JNX::JLog::debug;

    my $timenow = time();
    
    if( $timenow < ($self->{cachetime} + $self->{urldate}) )
    {
        JNX::JLog::trace "no need to update.";

        return undef;
    }
    
    $self->{urldate}    = time();
    $self->{jsonhash}   = undef;

    JNX::JLog::trace "URL: $self->{url}";


    my $urldata;

#    if( length($self->{username}) > 0 )
#    {
#        $urldata = qx(curl -s -u $self->{username}:$self->{password} "$self->{url}");
#    }
#    else
    {
        $urldata = qx(curl -s "$self->{url}");
    }
    JNX::JLog::trace "URLData: $urldata";

    $self->{jsonhash} = JNX::JSONHelper::hashFromJSONString($urldata);
    JNX::JLog::trace "JSONHash".Data::Dumper->Dumper($self->{jsonhash});
}


1;
