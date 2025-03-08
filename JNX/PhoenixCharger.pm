#!/usr/bin/perl

use strict;
use Time::HiRes qw(usleep);
use POSIX;
use Data::Dumper;
use JNX::Configuration;
use JNX::JLog;

package JNX::PhoenixCharger;

use parent 'JNX::ModbusDevice';

use constant EV_CAR_STATUS              => 100;
use constant PROXIMITY_CHARGING_CURRENT => 101;
use constant MANUAL_CHARGING_BUTTON     => 200;
use constant CHARGE_CURRENT             => 300;
use constant ENABLE_CHARGING            => 400;

my %commandlineoption = JNX::Configuration::newFromDefaults(
                                                                'PhoenixAddress'        => [undef,'string'],
                                                                'PhoenixName'           => ['evcharger','string'],
                                                            );
sub new
{
    my ($class,%options) = (@_);

    $options{host}                  = $commandlineoption{'PhoenixAddress'}  || die "No PhoenixAddress set";
    $options{devicename}            = $commandlineoption{'PhoenixName'}     || die "No PhoenixAddress set";

    $options{debug}                 = $commandlineoption{'debug'};

    $options{id}             = 180;
    $options{inputregisters} = {
                        JNX::PhoenixCharger::EV_CAR_STATUS               => { modbussize => 8,   wordcount => 1  ,modbustype => 'register', valuetype => 'char',  access=>'r',    description => 'EV car status'},
                        JNX::PhoenixCharger::PROXIMITY_CHARGING_CURRENT  => { modbussize => 16,  wordcount => 1  ,modbustype => 'register', valuetype => 'UInt16', access=>'r',    description => 'Proximity charging current (Ampere)' },

                        102 => { modbussize => 32,  wordcount => 1  ,modbustype => 'register', valuetype => 'UInt32', access=>'r',    description => 'Charge time (seconds)' },

                        104 => { modbussize => 16,  wordcount => 1  ,modbustype => 'register', valuetype => 'bit',    access=>'r',    description => 'Dip switches'},
                        105 => { modbussize => 32,  wordcount => 1  ,modbustype => 'register', valuetype => 'decimal', access=>'r',   description => 'Firmware version'},
                        107 => { modbussize => 16,  wordcount => 1  ,modbustype => 'register', valuetype => 'bit',    access=>'r',    description => 'Error Codes'},

                        108 => { modbussize => 32,  wordcount => 1  ,modbustype => 'register', valuetype => 'decimal', access=>'r',   description => 'Display meter voltage V1'},
                        114 => { modbussize => 32,  wordcount => 1  ,modbustype => 'register', valuetype => 'decimal', access=>'r',   description => 'Display meter current I1'},

                        132 => { modbussize => 32,  wordcount => 1  ,modbustype => 'register', valuetype => 'decimal', access=>'r',   description => 'Energy of current charging process'},
                        134 => { modbussize => 32,  wordcount => 1  ,modbustype => 'register', valuetype => 'UInt32', access=>'r',    description => 'Current Frequency' },

                        JNX::PhoenixCharger::MANUAL_CHARGING_BUTTON => { modbussize => 1,  wordcount => 1  ,modbustype => 'discrete', valuetype => 'UInt32', access=>'r',    description => 'Digital input EN (Enable)' },
                        201 => { modbussize => 1,  wordcount => 1  ,modbustype => 'discrete', valuetype => 'UInt32', access=>'r',    description => 'Digital input XR (External Release)' },
                        202 => { modbussize => 1,  wordcount => 1  ,modbustype => 'discrete', valuetype => 'UInt32', access=>'r',    description => 'Digital input LD (Lock Detection)' },
                        203 => { modbussize => 1,  wordcount => 1  ,modbustype => 'discrete', valuetype => 'UInt32', access=>'r',    description => 'Digital input ML (Manual Lock)' },
                        204 => { modbussize => 1,  wordcount => 1  ,modbustype => 'discrete', valuetype => 'UInt32', access=>'r',    description => 'Digital output CR (Charger Ready)' },
                        205 => { modbussize => 1,  wordcount => 1  ,modbustype => 'discrete', valuetype => 'UInt32', access=>'r',    description => 'Digital output LR (Locking Re- quest)' },
                        206 => { modbussize => 1,  wordcount => 1  ,modbustype => 'discrete', valuetype => 'UInt32', access=>'r',    description => 'Digital output VR (Vehicle Ready)' },
                        207 => { modbussize => 1,  wordcount => 1  ,modbustype => 'discrete', valuetype => 'UInt32', access=>'r',    description => 'Digital output ER (Error)' },


                        JNX::PhoenixCharger::CHARGE_CURRENT => { modbussize => 16,  wordcount => 1  ,modbustype => 'holding',  valuetype => 'UInt16', access=>'rw',    description => 'charging current (Ampere)' },
                        301 => { modbussize => 16,  wordcount => 3  ,modbustype => 'holding',  valuetype => 'hex',    access=>'rw',    description => 'MAC Address'},
                        304 => { modbussize => 8,  wordcount => 6  ,modbustype => 'holding',  valuetype => 'ascii',  access=>'rw',    description => 'Serial number'},
                        310 => { modbussize => 16,  wordcount => 6  ,modbustype => 'holding',  valuetype => 'ascii',  access=>'rw',    description => 'Device name'},
                        315 => { modbussize => 8,  wordcount => 4  ,modbustype => 'holding',  valuetype => 'UInt32', access=>'rw',    description => 'IP:address'},
                        319 => { modbussize => 8,  wordcount => 4  ,modbustype => 'holding',  valuetype => 'UInt32', access=>'rw',    description => 'IP:netmask'},
                        323 => { modbussize => 8,  wordcount => 4  ,modbustype => 'holding',  valuetype => 'UInt32', access=>'rw',    description => 'IP:Gateway'},

                        327 => { modbussize => 16,  wordcount => 1  ,modbustype => 'holding',  valuetype => 'UInt32', access=>'rw',    description => 'Definition of output CR' },
                        328 => { modbussize => 16,  wordcount => 1  ,modbustype => 'holding',  valuetype => 'UInt32', access=>'rw',    description => 'Definition of output LR' },
                        329 => { modbussize => 16,  wordcount => 1  ,modbustype => 'holding',  valuetype => 'UInt32', access=>'rw',    description => 'Definition of output VR' },
                        330 => { modbussize => 16,  wordcount => 1  ,modbustype => 'holding',  valuetype => 'UInt32', access=>'rw',    description => 'Definition of output ER' },


                        JNX::PhoenixCharger::ENABLE_CHARGING => { modbussize => 1,  wordcount => 1  ,modbustype => 'coil',  valuetype => 'UInt32', access=>'rw',    description => 'Enable charging process' },
                        401 => { modbussize => 1,  wordcount => 1  ,modbustype => 'coil',  valuetype => 'UInt32', access=>'rw',    description => 'Request digital communication' },
                        402 => { modbussize => 1,  wordcount => 1  ,modbustype => 'coil',  valuetype => 'UInt32', access=>'rw',    description => 'Charging station available' },
                        403 => { modbussize => 1,  wordcount => 1  ,modbustype => 'coil',  valuetype => 'UInt32', access=>'rw',    description => 'Manual locking' },
                        404 => { modbussize => 1,  wordcount => 1  ,modbustype => 'coil',  valuetype => 'UInt32', access=>'rw',    description => 'Switch DHCP on/off' },
                        405 => { modbussize => 1,  wordcount => 1  ,modbustype => 'coil',  valuetype => 'UInt32', access=>'rw',    description => 'Output 1' },
                        406 => { modbussize => 1,  wordcount => 1  ,modbustype => 'coil',  valuetype => 'UInt32', access=>'rw',    description => 'Output 2' },
                        407 => { modbussize => 1,  wordcount => 1  ,modbustype => 'coil',  valuetype => 'UInt32', access=>'rw',    description => 'Output 3' },
                        408 => { modbussize => 1,  wordcount => 1  ,modbustype => 'coil',  valuetype => 'UInt32', access=>'rw',    description => 'Output 4' },
                        409 => { modbussize => 1,  wordcount => 1  ,modbustype => 'coil',  valuetype => 'UInt32', access=>'rw',    description => 'Activate overcurrent shutdown' },
                        410 => { modbussize => 1,  wordcount => 1  ,modbustype => 'coil',  valuetype => 'UInt32', access=>'rw',    description => 'Little/big Endian' },
                        411 => { modbussize => 1,  wordcount => 1  ,modbustype => 'coil',  valuetype => 'UInt32', access=>'rw',    description => 'Voltage in status A/B detected activated' },
                        412 => { modbussize => 1,  wordcount => 1  ,modbustype => 'coil',  valuetype => 'UInt32', access=>'rw',    description => 'Status D, reject vehicle activated' },
                        413 => { modbussize => 1,  wordcount => 1  ,modbustype => 'coil',  valuetype => 'UInt32', access=>'rw',    description => 'reset charging controller' },
                        414 => { modbussize => 1,  wordcount => 1  ,modbustype => 'coil',  valuetype => 'UInt32', access=>'rw',    description => 'Voltage in status A/B detected' },
                        415 => { modbussize => 1,  wordcount => 1  ,modbustype => 'coil',  valuetype => 'UInt32', access=>'rw',    description => 'Status D vehicle rejected' },
                        416 => { modbussize => 1,  wordcount => 1  ,modbustype => 'coil',  valuetype => 'UInt32', access=>'rw',    description => 'pulsed/permanent input signal' },
                    };

    my $self = $class->SUPER::new( %options );
    
    return $self;
}

sub reset
{
    my($self) = @_;

    my $command = 'http://'.$self->{host}.'/config.html?reset=1' ;
    JNX::JLog::error "reset: trying to reset Phoenix charger: $command";
    
    qx(curl -s "$command");
}


sub car_is_connected
{
    my($self) = @_;
    my $value = $self->readAddress(JNX::PhoenixCharger::EV_CAR_STATUS);

    JNX::JLog::debug "car_is_connected: read:".Data::Dumper->Dumper($value);
    
    my $returnvalue = ($value =~ /^[B-F]$/ ? 1 : 0);
    
    JNX::JLog::debug "car_is_connected:".$returnvalue;
    return $returnvalue;
}



sub car_is_charging
{
    my($self) = @_;
    my $value = $self->readAddress(JNX::PhoenixCharger::EV_CAR_STATUS);

    JNX::JLog::debug "car_is_charging: read:".Data::Dumper->Dumper($value);

    my $returnvalue = ($value =~ /^[CD]$/ ? 1 : 0);

    JNX::JLog::debug "car_is_charging:".$returnvalue;
    return $returnvalue;
}



sub automatic_charging_enabled
{
    my($self) = @_;
    
    my $value = $self->manual_charging_button ? 0 : 1;

    JNX::JLog::debug "automatic_charging: :".Data::Dumper->Dumper($value);

    return $value;
}



sub manual_charging_button
{
    my($self) = @_;
    my $value = $self->readAddress(JNX::PhoenixCharger::MANUAL_CHARGING_BUTTON) ? 1 : 0;

    JNX::JLog::debug "manual_charging_button: :".Data::Dumper->Dumper($value);

    return $value;
}



sub charging_is_enabled
{
    my($self) = @_;
    my $value = $self->readAddress(JNX::PhoenixCharger::ENABLE_CHARGING) ? 1 : 0;

    JNX::JLog::debug "charging_is_enabled: :".Data::Dumper->Dumper($value);

    return $value;
}



sub set_charging_enabled
{
    my($self,$givenValue) = @_;

    my $newValue = $givenValue ? 1 : 0;
    
    JNX::JLog::debug "set_charging_enabled: should set:".Data::Dumper->Dumper($newValue);

    my $currentvalue = $self->charging_is_enabled();

    if( $currentvalue == $newValue )
    {
        JNX::JLog::debug "set_charging_enabled: won't set: currentvalue == newvalue ( $currentvalue == $newValue )";
        return $currentvalue
    }

    my $value = $self->writeAddress(JNX::PhoenixCharger::ENABLE_CHARGING,$newValue);

    JNX::JLog::debug "set_charging_enabled: did set:".Data::Dumper->Dumper($value);

    return $value;
}




sub current_charge_current
{
    my($self) = @_;
    my $value = $self->readAddress(JNX::PhoenixCharger::CHARGE_CURRENT);

    JNX::JLog::debug "current_charge_current: :".Data::Dumper->Dumper($value);

    return $value;
}

sub set_charge_current
{
    my($self,$newValue) = @_;
    
    Carp::croak "Invalid set current: $newValue" if $newValue < 6 || $newValue > 32;
    
    my $currentvalue = $self->current_charge_current();
    
    if( $currentvalue == $newValue )
    {
        JNX::JLog::debug "set_charge_current: won't set: currentvalue == newvalue ( $currentvalue == $newValue )";
        return $currentvalue
    }
    
    my $value = $self->writeAddress(JNX::PhoenixCharger::CHARGE_CURRENT,$newValue);

    JNX::JLog::debug "set_charge_current: :".Data::Dumper->Dumper($value);
    
    return $value;
}

1;


