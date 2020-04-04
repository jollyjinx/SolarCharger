#!/usr/bin/perl

use strict;
use Time::HiRes qw(usleep);
use POSIX;
use Data::Dumper;
use JNX::Configuration;

package JNX::PhoenixCharger;

use parent 'JNX::ModbusDevice';

use constant EV_CAR_STATUS              => 100;
use constant PROXIMITY_CHARGING_CURRENT => 101;
use constant MANUAL_CHARGING_BUTTON     => 200;
use constant CHARGE_CURRENT             => 300;
use constant ENABLE_CHARGING            => 400;

my %commandlineoption = JNX::Configuration::newFromDefaults(
                                                                'PhoenixAddress'        => [undef,'string'],
                                                            );
sub new
{
    my ($class,%options) = (@_);

    $options{host}                  = $commandlineoption{'PhoenixAddress'} || die "No PhoenixAddress set";
    $options{debug}                 = $commandlineoption{'debug'};

    $options{id}             = 180;
    $options{inputregisters} = {
                        JNX::PhoenixCharger::EV_CAR_STATUS               => { modbussize => 8,   wordcount => 1  ,modbustype => 'register', contenttype => 'ascii',  access=>'r',    name => 'EV car status'},
                        JNX::PhoenixCharger::PROXIMITY_CHARGING_CURRENT  => { modbussize => 16,  wordcount => 1  ,modbustype => 'register', contenttype => 'UInt32', access=>'r',    name => 'Proximity charging current (Ampere)' },

                        102 => { modbussize => 32,  wordcount => 1  ,modbustype => 'register', contenttype => 'UInt32', access=>'r',    name => 'Charge time (seconds)' },

                        104 => { modbussize => 16,  wordcount => 1  ,modbustype => 'register', contenttype => 'bit',    access=>'r',    name => 'Dip switches'},
                        105 => { modbussize => 32,  wordcount => 1  ,modbustype => 'register', contenttype => 'decimal', access=>'r',   name => 'Firmware version'},
                        107 => { modbussize => 16,  wordcount => 1  ,modbustype => 'register', contenttype => 'bit',    access=>'r',    name => 'Error Codes'},

                        108 => { modbussize => 32,  wordcount => 1  ,modbustype => 'register', contenttype => 'decimal', access=>'r',   name => 'Display meter voltage V1'},
                        114 => { modbussize => 32,  wordcount => 1  ,modbustype => 'register', contenttype => 'decimal', access=>'r',   name => 'Display meter current I1'},

                        132 => { modbussize => 32,  wordcount => 1  ,modbustype => 'register', contenttype => 'decimal', access=>'r',   name => 'Energy of current charging process'},
                        134 => { modbussize => 32,  wordcount => 1  ,modbustype => 'register', contenttype => 'UInt32', access=>'r',    name => 'Current Frequency' },

                        JNX::PhoenixCharger::MANUAL_CHARGING_BUTTON => { modbussize => 1,  wordcount => 1  ,modbustype => 'discrete', contenttype => 'UInt32', access=>'r',    name => 'Digital input EN (Enable)' },
                        201 => { modbussize => 1,  wordcount => 1  ,modbustype => 'discrete', contenttype => 'UInt32', access=>'r',    name => 'Digital input XR (External Release)' },
                        202 => { modbussize => 1,  wordcount => 1  ,modbustype => 'discrete', contenttype => 'UInt32', access=>'r',    name => 'Digital input LD (Lock Detection)' },
                        203 => { modbussize => 1,  wordcount => 1  ,modbustype => 'discrete', contenttype => 'UInt32', access=>'r',    name => 'Digital input ML (Manual Lock)' },
                        204 => { modbussize => 1,  wordcount => 1  ,modbustype => 'discrete', contenttype => 'UInt32', access=>'r',    name => 'Digital output CR (Charger Ready)' },
                        205 => { modbussize => 1,  wordcount => 1  ,modbustype => 'discrete', contenttype => 'UInt32', access=>'r',    name => 'Digital output LR (Locking Re- quest)' },
                        206 => { modbussize => 1,  wordcount => 1  ,modbustype => 'discrete', contenttype => 'UInt32', access=>'r',    name => 'Digital output VR (Vehicle Ready)' },
                        207 => { modbussize => 1,  wordcount => 1  ,modbustype => 'discrete', contenttype => 'UInt32', access=>'r',    name => 'Digital output ER (Error)' },


                        JNX::PhoenixCharger::CHARGE_CURRENT => { modbussize => 16,  wordcount => 1  ,modbustype => 'holding',  contenttype => 'UInt32', access=>'rw',    name => 'charging current (Ampere)' },
                        301 => { modbussize => 16,  wordcount => 3  ,modbustype => 'holding',  contenttype => 'hex',    access=>'rw',    name => 'MAC Address'},
                        304 => { modbussize => 8,  wordcount => 6  ,modbustype => 'holding',  contenttype => 'ascii',  access=>'rw',    name => 'Serial number'},
                        310 => { modbussize => 16,  wordcount => 6  ,modbustype => 'holding',  contenttype => 'ascii',  access=>'rw',    name => 'Device name'},
                        315 => { modbussize => 8,  wordcount => 4  ,modbustype => 'holding',  contenttype => 'UInt32', access=>'rw',    name => 'IP:address'},
                        319 => { modbussize => 8,  wordcount => 4  ,modbustype => 'holding',  contenttype => 'UInt32', access=>'rw',    name => 'IP:netmask'},
                        323 => { modbussize => 8,  wordcount => 4  ,modbustype => 'holding',  contenttype => 'UInt32', access=>'rw',    name => 'IP:Gateway'},

                        327 => { modbussize => 16,  wordcount => 1  ,modbustype => 'holding',  contenttype => 'UInt32', access=>'rw',    name => 'Definition of output CR' },
                        328 => { modbussize => 16,  wordcount => 1  ,modbustype => 'holding',  contenttype => 'UInt32', access=>'rw',    name => 'Definition of output LR' },
                        329 => { modbussize => 16,  wordcount => 1  ,modbustype => 'holding',  contenttype => 'UInt32', access=>'rw',    name => 'Definition of output VR' },
                        330 => { modbussize => 16,  wordcount => 1  ,modbustype => 'holding',  contenttype => 'UInt32', access=>'rw',    name => 'Definition of output ER' },


                        JNX::PhoenixCharger::ENABLE_CHARGING => { modbussize => 1,  wordcount => 1  ,modbustype => 'coil',  contenttype => 'UInt32', access=>'rw',    name => 'Enable charging process' },
                        401 => { modbussize => 1,  wordcount => 1  ,modbustype => 'coil',  contenttype => 'UInt32', access=>'rw',    name => 'Request digital communication' },
                        402 => { modbussize => 1,  wordcount => 1  ,modbustype => 'coil',  contenttype => 'UInt32', access=>'rw',    name => 'Charging station available' },
                        403 => { modbussize => 1,  wordcount => 1  ,modbustype => 'coil',  contenttype => 'UInt32', access=>'rw',    name => 'Manual locking' },
                        404 => { modbussize => 1,  wordcount => 1  ,modbustype => 'coil',  contenttype => 'UInt32', access=>'rw',    name => 'Switch DHCP on/off' },
                        405 => { modbussize => 1,  wordcount => 1  ,modbustype => 'coil',  contenttype => 'UInt32', access=>'rw',    name => 'Output 1' },
                        406 => { modbussize => 1,  wordcount => 1  ,modbustype => 'coil',  contenttype => 'UInt32', access=>'rw',    name => 'Output 2' },
                        407 => { modbussize => 1,  wordcount => 1  ,modbustype => 'coil',  contenttype => 'UInt32', access=>'rw',    name => 'Output 3' },
                        408 => { modbussize => 1,  wordcount => 1  ,modbustype => 'coil',  contenttype => 'UInt32', access=>'rw',    name => 'Output 4' },
                        409 => { modbussize => 1,  wordcount => 1  ,modbustype => 'coil',  contenttype => 'UInt32', access=>'rw',    name => 'Activate overcurrent shutdown' },
                        410 => { modbussize => 1,  wordcount => 1  ,modbustype => 'coil',  contenttype => 'UInt32', access=>'rw',    name => 'Little/big Endian' },
                        411 => { modbussize => 1,  wordcount => 1  ,modbustype => 'coil',  contenttype => 'UInt32', access=>'rw',    name => 'Voltage in status A/B detected activated' },
                        412 => { modbussize => 1,  wordcount => 1  ,modbustype => 'coil',  contenttype => 'UInt32', access=>'rw',    name => 'Status D, reject vehicle activated' },
                        413 => { modbussize => 1,  wordcount => 1  ,modbustype => 'coil',  contenttype => 'UInt32', access=>'rw',    name => 'reset charging controller' },
                        414 => { modbussize => 1,  wordcount => 1  ,modbustype => 'coil',  contenttype => 'UInt32', access=>'rw',    name => 'Voltage in status A/B detected' },
                        415 => { modbussize => 1,  wordcount => 1  ,modbustype => 'coil',  contenttype => 'UInt32', access=>'rw',    name => 'Status D vehicle rejected' },
                        416 => { modbussize => 1,  wordcount => 1  ,modbustype => 'coil',  contenttype => 'UInt32', access=>'rw',    name => 'pulsed/permanent input signal' },
                    };

    my $self = $class->SUPER::new( %options );
    
    return $self;
}

sub reset
{
    my($self) = @_;

    my $command = 'http://'.$self->{host}.'/config.html?reset=1' ;
    print STDERR "reset: trying to reset Phoenix charger: $command \n";
    
    qx(curl -s "$command");
}


sub car_is_connected
{
    my($self) = @_;
    my $value = shift $self->readAddress(JNX::PhoenixCharger::EV_CAR_STATUS);

    print STDERR "car_is_connected: read:".Data::Dumper->Dumper($value)."\n" if $self->{debug};
    
    my $returnvalue = ($value =~ /^[B-F]$/ ? 1 : 0);
    
    print STDERR "car_is_connected:".$returnvalue."\n" if $self->{debug};
    return $returnvalue;
}



sub car_is_charging
{
    my($self) = @_;
    my $value = shift $self->readAddress(JNX::PhoenixCharger::EV_CAR_STATUS);

    print STDERR "car_is_charging: read:".Data::Dumper->Dumper($value)."\n" if $self->{debug};

    my $returnvalue = ($value =~ /^[CD]$/ ? 1 : 0);

    print STDERR "car_is_charging:".$returnvalue."\n" if $self->{debug};
    return $returnvalue;
}



sub automatic_charging_enabled
{
    my($self) = @_;
    
    my $value = $self->manual_charging_button ? 0 : 1;

    print STDERR "automatic_charging: :".Data::Dumper->Dumper($value)."\n" if $self->{debug};

    return $value;
}



sub manual_charging_button
{
    my($self) = @_;
    my $value = (shift $self->readAddress(JNX::PhoenixCharger::MANUAL_CHARGING_BUTTON)) ? 1 : 0;

    print STDERR "manual_charging_button: :".Data::Dumper->Dumper($value)."\n" if $self->{debug};

    return $value;
}



sub charging_is_enabled
{
    my($self) = @_;
    my $value = ( shift $self->readAddress(JNX::PhoenixCharger::ENABLE_CHARGING) ) ? 1 : 0;

    print STDERR "charging_is_enabled: :".Data::Dumper->Dumper($value)."\n" if $self->{debug};

    return $value;
}



sub set_charging_enabled
{
    my($self,$givenValue) = @_;

    my $newValue = $givenValue ? 1 : 0;
    
    print STDERR "set_charging_enabled: should set:".Data::Dumper->Dumper($newValue)."\n" if $self->{debug};

    my $currentvalue = $self->charging_is_enabled();

    if( $currentvalue == $newValue )
    {
        print STDERR "set_charging_enabled: won't set: currentvalue == newvalue ( $currentvalue == $newValue )\n" if $self->{debug};
        return $currentvalue
    }

    my $value = $self->writeAddress(JNX::PhoenixCharger::ENABLE_CHARGING,$newValue);

    print STDERR "set_charging_enabled: did set:".Data::Dumper->Dumper($value)."\n" if $self->{debug};

    return $value;
}




sub current_charge_current
{
    my($self) = @_;
    my $value = shift $self->readAddress(JNX::PhoenixCharger::CHARGE_CURRENT);

    print STDERR "current_charge_current: :".Data::Dumper->Dumper($value)."\n" if $self->{debug};

    return $value;
}

sub set_charge_current
{
    my($self,$newValue) = @_;
    
    Carp::croak "Invalid set current: $newValue" if $newValue < 6 || $newValue > 32;
    
    my $currentvalue = $self->current_charge_current();
    
    if( $currentvalue == $newValue )
    {
        print STDERR "set_charge_current: won't set: currentvalue == newvalue ( $currentvalue == $newValue )\n" if $self->{debug};
        return $currentvalue
    }
    
    my $value = $self->writeAddress(JNX::PhoenixCharger::CHARGE_CURRENT,$newValue);

    print STDERR "set_charge_current: :".Data::Dumper->Dumper($value)."\n" if $self->{debug};
    
    return $value;
}

1;


