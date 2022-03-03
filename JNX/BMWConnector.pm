#!/usr/bin/perl

use strict;
use Carp;

package JNX::BMWConnector;
use Math::Trig qw(deg2rad pi);
use JSON::PP;

use JNX::JLog;
use JNX::Configuration;


my %commandlineoption = JNX::Configuration::newFromDefaults(
                                                                'url'               => ['https://example.com/bmw.json','string'],
                                                                'username'          => ['john.doe','string'],
                                                                'password'          => ['mynameismypassword','string'],

                                                                'homelatitude'      => [48.137265,'number'],
                                                                'homelongitude'     => [11.575455,'number'],
                                                                'homeradiusmeter'   => [500,'number'],

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
    
    $self->{homelatitude}   = $options{homelatitude}    || $commandlineoption{'homelatitude'};
    $self->{homelongitude}  = $options{homelongitude}   || $commandlineoption{'homelongitude'};
    $self->{homeradiusmeter}= $options{homeradiusmeter} || $commandlineoption{'homeradiusmeter'};

    $self->{chargelimit}    = $options{chargelimit}     || $commandlineoption{'chargelimit'};
    $self->{pvchargelimit}  = $options{pvchargelimit}   || $commandlineoption{'pvchargelimit'};

    $self->{cachetime}      = $options{cachetime}       || $commandlineoption{'cachetime'};
    $self->{outdatedtime}   = $options{outdatedtime}    || $commandlineoption{'outdatedtime'};

    JNX::JLog::trace("initalized:".Data::Dumper->Dumper($self));

    bless $self, $class;
    return $self;
}


sub isConnected             {   return @_[0]->getVariableFromKeyPath('dynamic.attributesMap.connectorStatus')    eq 'CONNECTED' ? 1 : 0;   }
sub isCharging              {   return @_[0]->getVariableFromKeyPath('dynamic.attributesMap.charging_status')    eq 'CHARGING'  ? 1 : 0;   }
sub currentStateOfCharge    {   return @_[0]->getVariableFromKeyPath('dynamic.attributesMap.chargingLevelHv') + 0.0;     }

sub carName
{
    my($self) = @_;
    JNX::JLog::trace;

    my %carnames = ( 'jolly' => 'Admiral', 'jolly2' => 'Blauwal' );
    my $carname = 'Unknown';
    if(     $self->{url} =~ m/([\w\d]+)\.json$/
        &&  exists( $carnames{$1} ) )
    {
        $carname = $carnames{$1}
    }
    JNX::JLog::debug("Carname:$carname");
    return $carname;
}

sub hasReachedChargeLimitAtHome
{
     my($self) = @_;
    JNX::JLog::trace;

     if(        $self->isConnected()
            &&  ($self->currentStateOfCharge() >= $self->{chargelimit} )
            &&  $self->isAtHome()
        )
    {
        JNX::JLog::debug 'hasReachedChargeLimitAtHome';
        return 1;
    }
    return 0;
}

sub hasReachedPVLimitAtHome
{
     my($self) = @_;
    JNX::JLog::trace;

     if(        $self->isConnected()
            &&  ($self->currentStateOfCharge() >= $self->{pvchargelimit} )
            &&  $self->isAtHome()
        )
    {
        JNX::JLog::debug 'hasReachedPVLimitAtHome';
        return 1;
    }
    return 0;
}

        
sub distanceFromLocationInKm
{
    my($lat1,$lon1,$lat2,$lon2) = @_;
    JNX::JLog::trace;

    my $R = 6371;                      # Radius of the earth in km
    my $dLat  = deg2rad($lat2-$lat1);   # deg2rad below
    my $dLon  = deg2rad($lon2-$lon1);
    my $a     =   sin($dLat/2) * sin($dLat/2) +
                  cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * sin($dLon/2) * sin($dLon/2); 
    my $c = 2 * atan2(sqrt($a), sqrt(1-$a));
    my $d = $R * $c;                    # Distance in km

    JNX::JLog::trace('distance: %3.2f km',$d);

    return $d;
}
                                                  
sub isAtHome
{
    my($self) = @_;
    JNX::JLog::trace;

    $self->updateDataIfNeeded();

    return $self->{data}{isAtHome} if $self->{data}{isAtHome};

    my $latitude     = $self->getVariableFromKeyPath('dynamic.attributesMap.gps_lat') + 0;
    my $longitude    = $self->getVariableFromKeyPath('dynamic.attributesMap.gps_lng') + 0;

    printf STDERR "%s Location: %6.4f %6.4f\n",''.localtime(),$latitude,$latitude if $self->{debug};

    my $distance = distanceFromLocationInKm($self->{homelatitude},$self->{homelongitude},$latitude,$longitude);
    
    my $isathome = $distance < $self->{homeradiusmeter} ? 1 : 0;
     
    JNX::JLog::debug("Distance from home: %6.4f isAtHome:%d",$distance,$isathome);
    
    $self->{data}{isAtHome} = $isathome;
     return $isathome;
}


sub getVariableFromKeyPath
{
    my($self,$keypath) = @_;
    JNX::JLog::trace 'keypath'.$keypath;

    $self->updateDataIfNeeded();
    return $self->{data}{$keypath} if $self->{data}{$keypath};
    
    my $path = '{'.$keypath.'}';
    $path =~ s/\./}{/g;
    my $value = undef;
    my $evaluating = '$value = $self->{jsonhash}'.$path;
    JNX::JLog::trace 'evaluating:'.$evaluating;
    eval "$evaluating";

    JNX::JLog::trace 'value:'.$value;
    $self->{data}{$keypath} = $value;
    return $value; 
}

sub getVariableFromURLData
{
    my($self,$variablename) = @_;
    JNX::JLog::trace 'variablename:'.$variablename;

    $self->updateDataIfNeeded();
    return $self->{data}{$variablename} if $self->{data}{$variablename};

    $self->{data}{$variablename} = $1 if $self->{data}{urldata} =~ m/^\s*"\Q$variablename\E"\s*:\s*"(.*?)",/m;
    return $self->{data}{$variablename};
}


sub updateDataIfNeeded
{
    my($self) = @_;
    JNX::JLog::trace;

    my $timenow = time();
    
    return undef if $timenow < ($self->{cachetime} + $self->{data}{urldate});
    
    $self->{data} = undef;
    
    my $urldata     = qx(curl -s -u $self->{username}:$self->{password} "$self->{url}");
    my $urltime     = time();

    $urldata =~ s/^\s+(.*?)\s+$/\1/gs;
    my $jsonhash;
     
    JNX::JLog::trace "jsonstring:".Data::Dumper->Dumper($urldata);
    eval { $jsonhash = JSON::PP->new->utf8(1)->decode( $urldata ); };
    JNX::JLog::trace "jsonhash:".Data::Dumper->Dumper($jsonhash);
    
    $self->{data}{urldate} = $urltime;
    $self->{jsonhash}   = $jsonhash;

    my $bmwtime     = $1 if $urldata =~ m/"updateTime_converted_timestamp"\s+:\s+"(\d{10})\d{3}",/om;
    
    $bmwtime = $bmwtime - 3600;   # for whatever reaseon bmw server is one hour off
    
    if( ($urltime - $bmwtime) < $self->{outdatedtime} )
    {
        JNX::JLog::debug "BMW Time $bmwtime == ".localtime($bmwtime);
    
        $self->{data}{urldata} = $urldata;
    }
    else
    {
        JNX::JLog::debug "BMW Data too old BMW Time $bmwtime == ".localtime($bmwtime);
    }
}


1;
