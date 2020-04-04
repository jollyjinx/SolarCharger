#!/usr/bin/perl

use strict;
use JNX::ModbusDevice;
use Time::HiRes;
use POSIX;
use Data::Dumper;
use JNX::Configuration;

package JNX::SMAReader;
use parent 'JNX::ModbusDevice';

use constant DEVICE_TYPE_ID             => 30051;
use constant DEVICE_TYPE_SOLAR_ID       =>  8001;
use constant DEVICE_TYPE_SOLAR          => 'solar';
use constant DEVICE_TYPE_BATTERY        => 'battery';

use constant POWER_LIMITATION           => 40212;
use constant CURRENT_GENERATION         => 30775;
use constant GRID_CURRENT_PHASE_A       => 31253;
use constant CURRENT_FEEDIN             => 30867;
use constant CURRENT_GRID_USAGE         => 30865;
use constant TOTAL_YIELD_COUNTER        => 30513;
use constant TOTAL_FEEDIN_COUNTER       => 30583;
use constant TOTAL_GRID_COUNTER         => 30581;


my %commandlineoption = JNX::Configuration::newFromDefaults(
                                                                'SMAAddress'        => [undef,'string'],
                                                            );
sub new
{
    my ($class,%options) = (@_);

    $options{host}                  = $commandlineoption{'SMAAddress'} || die "No SMAAddress set";
    $options{debug}                 = $commandlineoption{'debug'};

    $options{id}                    = 3;
    $options{maximum_backgroundsize}= $options{maximum_backgroundsize} || 1000;

    $options{inputregisters} = {
                                    JNX::SMAReader::DEVICE_TYPE_ID => { modbussize => 32,  wordcount => 2, contenttype => 'UInt32',    modbustype => 'register', access=>'r', loop => 0, devicetype => 'all',     name => 'Device class'           },
                                    30213 => { modbussize => 32,  wordcount => 2, contenttype => 'UInt32',    modbustype => 'register', access=>'r', loop => 0, devicetype => 'all',     name => 'Current Error (886=no message)' },
                                    30053 => { modbussize => 32,  wordcount => 2, contenttype => 'UInt32',    modbustype => 'register', access=>'r', loop => 0, devicetype => 'all',     name => 'Device type'           },
                                    30057 => { modbussize => 32,  wordcount => 2, contenttype => 'UInt32',    modbustype => 'register', access=>'r', loop => 0, devicetype => 'all',     name => 'Serial number'         },
                                    40631 => { modbussize => 8,,  wordcount => 12,contenttype => 'ascii',     modbustype => 'register', access=>'r', loop => 0, devicetype => 'all',     name => 'Name'                  },
                                    40647 => { modbussize => 32,  wordcount => 2, contenttype => 'UInt32',    modbustype => 'register', access=>'r', loop => 0, devicetype => 'all',     name => 'Automatic updates YES:1129 No:1130'     },

                                    31405 => { modbussize => 32,  wordcount => 2, contenttype => 'SInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'solar',   name => 'Current Limitation (W)'     },
#                                    40016 => { modbussize => 16,  wordcount => 1, contenttype => 'SInt16',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'solar',   name => 'Power Limitation (W)'     },
#                                    30835 => { modbussize => 32,  wordcount => 2, contenttype => 'UInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'solar',   name => '30835'     },
#                                    30837 => { modbussize => 32,  wordcount => 2, contenttype => 'UInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'solar',   name => '30837'     },
#                                    30839 => { modbussize => 32,  wordcount => 2, contenttype => 'UInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'solar',   name => '30839'     },
#                                    40015 => { modbussize => 32,  wordcount => 2, contenttype => 'UInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'solar',   name => '40015'     },

                                    JNX::SMAReader::POWER_LIMITATION => { modbussize => 32,  wordcount => 2, contenttype => 'UInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'solar',   name => 'Power Limitation (W)'     },
                                    30233 => { modbussize => 32,  wordcount => 2, contenttype => 'UInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'solar',   name => 'Active Limitation (W)'     },
                                    30231 => { modbussize => 32,  wordcount => 2, contenttype => 'UInt32',    modbustype => 'register', access=>'r', loop => 0, devicetype => 'solar',   name => 'Maximum Power (W)'     },
                                    30803 => { modbussize => 32,  wordcount => 2, contenttype => 'UInt32',    modbustype => 'register', access=>'r', loop => 0, devicetype => 'all',     name => 'Grid frequency (Hz)'      },
                                    JNX::SMAReader::GRID_CURRENT_PHASE_A => { modbussize => 32,  wordcount => 2, contenttype => 'UInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'solar',   name => 'Grid current (V) Phase A'},
                                    31255 => { modbussize => 32,  wordcount => 2, contenttype => 'UInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'solar',   name => 'Grid current (V) Phase B'},
                                    31257 => { modbussize => 32,  wordcount => 2, contenttype => 'UInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'solar',   name => 'Grid current (V) Phase C'},

#                                    30517 => { modbussize => 64,  wordcount => 4, contenttype => 'UInt64',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'solar',   name => 'Daily yield(Wh)'       },
                                     30535 => { modbussize => 32,  wordcount => 2, contenttype => 'UInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'solar',   name => 'Daily yield(Wh)'       },
                                     JNX::SMAReader::TOTAL_YIELD_COUNTER => { modbussize => 64,  wordcount => 4, contenttype => 'UInt64',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'solar',   name => 'Total yield(Wh)'       },

                                    JNX::SMAReader::TOTAL_GRID_COUNTER => { modbussize => 32,  wordcount => 2, contenttype => 'UInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'solar',   name => 'Grid Counter (Wh)'     },
                                    JNX::SMAReader::TOTAL_FEEDIN_COUNTER => { modbussize => 32,  wordcount => 2, contenttype => 'UInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'solar',   name => 'Feed in Counter (Wh)'  },
                                    JNX::SMAReader::CURRENT_GENERATION => { modbussize => 32,  wordcount => 2, contenttype => 'SInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'solar',   name => 'AC Power (W)'          },

#                                    30571 => { modbussize => 32,  wordcount => 2, contenttype => 'UInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'all',   name => 'Current self-consumption (W)'          },
#
#                                    30861 => { modbussize => 32,  wordcount => 2, contenttype => 'SInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'all',   name => 'Load power (W)'          },
#                                    30863 => { modbussize => 32,  wordcount => 2, contenttype => 'UInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'all',   name => 'Current PV array power (W)'          },
#                                    JNX::SMAReader::CURRENT_GRID_USAGE => { modbussize => 32,  wordcount => 2, contenttype => 'SInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'all',   name => 'Power purchased electricity (W)'          },
#                                    JNX::SMAReader::CURRENT_FEEDIN => { modbussize => 32,  wordcount => 2, contenttype => 'SInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'all',   name => 'Power grid feed-in (W)'          },
#                                    30869 => { modbussize => 32,  wordcount => 2, contenttype => 'SInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'all',   name => 'Power PV generation (W)'          },
#                                    30871 => { modbussize => 32,  wordcount => 2, contenttype => 'UInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'all',   name => 'Current self-consumption (W)'          },
#
#                                    30885 => { modbussize => 32,  wordcount => 2, contenttype => 'UInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'all',   name => 'Power of external grid connection (W)'          },
#                                    30983 => { modbussize => 32,  wordcount => 2, contenttype => 'UInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'all',   name => 'PV power (W)'          },
#
#                                    31091 => { modbussize => 32,  wordcount => 2, contenttype => 'SInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'all',   name => '31091 (W)'          },
#                                    31121 => { modbussize => 32,  wordcount => 2, contenttype => 'SInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'all',   name => '31121 (W)'          },
#                                    JNX::SMAReader::CURRENT_GENERATION => { modbussize => 32,  wordcount => 2, contenttype => 'SInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'solar',   name => 'Power (W)'          },


                                    30773 => { modbussize => 32,  wordcount => 2, contenttype => 'SInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'solar',   name => 'DC power1(W)'          },
                                    30961 => { modbussize => 32,  wordcount => 2, contenttype => 'SInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'solar',   name => 'DC power2(W)'          },
 
                                    34109 => { modbussize => 32,  wordcount => 2, contenttype => 'SInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'solar',   name => 'Heat sink temp(C)'     },
                                    34113 => { modbussize => 32,  wordcount => 2, contenttype => 'SInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'all',     name => 'Internal temp(C)'      },
#                                    34125 => { modbussize => 32,  wordcount => 2, contenttype => 'SInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'all',     name => 'External temp(C)'      },

                                    JNX::SMAReader::CURRENT_FEEDIN => { modbussize => 32,  wordcount => 2, contenttype => 'SInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'solar',   name => 'Feed in(W)'            },
                                    JNX::SMAReader::CURRENT_GRID_USAGE => { modbussize => 32,  wordcount => 2, contenttype => 'SInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'solar',   name => 'Grid usage(W)'         },

                                    31393 => { modbussize => 32,  wordcount => 2, contenttype => 'UInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'battery', name => 'Battery charge'        },
                                    31395 => { modbussize => 32,  wordcount => 2, contenttype => 'UInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'battery', name => 'Battery discharge'     },
                                    30845 => { modbussize => 32,  wordcount => 2, contenttype => 'UInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'battery', name => 'Battery soc in %'      },
                            };
    return $class->SUPER::new(%options);
}

sub currentType
{
    my($self) = @_;
    
    if( my $returnvalue = $self->readAddressFromCache(JNX::SMAReader::DEVICE_TYPE_ID) )
    {
        my $devicetype = @{$returnvalue}[0] == JNX::SMAReader::DEVICE_TYPE_SOLAR_ID  ? JNX::SMAReader::DEVICE_TYPE_SOLAR : JNX::SMAReader::DEVICE_TYPE_BATTERY;
    
        return $devicetype;
    }
    
    return undef;
}

sub sleepReading
{
    my($self,$sleeptime,$timeperstep) = @_;

    my $steptime = $timeperstep || 2;
    
   # print STDERR "steptime:$steptime sleeptime:$sleeptime\n";
    #exit;
    while($sleeptime > 0)
    {
        Time::HiRes::sleep( $steptime );
    
        $sleeptime -= $steptime;
        $self->readBackgroundData();
    }    
}


sub readBackgroundData
{
    my($self) = @_;

    my %hash;

    $hash{'time'}           = Time::HiRes::time();
#    $hash{'gridusage'}      = $self->current_gridusage();
#    $hash{'generation'}     = $self->current_generation();
#    $hash{'current_feedin'} = $self->current_feedin();
    
    push( @{$self->{backgoundData}},\%hash );

    my $maximumsize     = $self->{maximum_backgroundsize};
    my $backgroundsize  = scalar(@{$self->{backgoundData}});

    if( $backgroundsize > $maximumsize )
    {
        splice(@{$self->{backgoundData}}, 0, $backgroundsize - $maximumsize );
    }

    
    print STDERR "backgroundsize:".$backgroundsize."\n" if $self->{debug};
    print STDERR "backgroundsize:".Data::Dumper->Dumper($self->{backgoundData})."\n" ;
}



sub power_limititation
{
    my($self) = @_;
    
    my $value = shift $self->readAddress(JNX::SMAReader::POWER_LIMITATION);

    print STDERR "powerlimititation: :".Data::Dumper->Dumper($value)."\n" if $self->{debug};

    return $value;
}



sub current_generation
{
    my($self) = @_;
    my $value = shift $self->readAddress(JNX::SMAReader::CURRENT_GENERATION);

    print STDERR "current_generation: :".Data::Dumper->Dumper($value)."\n" if $self->{debug};

    return $value > 0 ? $value : 0;
}



sub current_gridvoltage
{
    my($self) = @_;
    my $value = shift $self->readAddress(JNX::SMAReader::GRID_CURRENT_PHASE_A);

    print STDERR "current_gridvoltage: :".Data::Dumper->Dumper($value)."\n" if $self->{debug};

    return ($value > 20000) && ($value < 25000) ? $value/100 : 230;
}



sub current_feedin
{
    my($self) = @_;
    my $value = shift $self->readAddress(JNX::SMAReader::CURRENT_FEEDIN);

    print STDERR "current_feedin: :".Data::Dumper->Dumper($value)."\n" if $self->{debug};

    return $value > 0 ? $value : 0;
}



sub current_gridusage
{
    my($self) = @_;
    my $value = shift $self->readAddress(JNX::SMAReader::CURRENT_GRID_USAGE);

    print STDERR "current_gridusage: :".Data::Dumper->Dumper($value)."\n" if $self->{debug};

    return $value > 0 ? $value : 0;
}

sub generation_counter
{
    my($self) = @_;
    my $value = shift $self->readAddress(JNX::SMAReader::TOTAL_YIELD_COUNTER);

    print STDERR "generation_counter: :".Data::Dumper->Dumper($value)."\n" if $self->{debug};

    return $value > 0 ? $value : 0;
}


sub feedin_counter
{
    my($self) = @_;
    my $value = shift $self->readAddress(JNX::SMAReader::TOTAL_FEEDIN_COUNTER);

    print STDERR "feedin_counter: :".Data::Dumper->Dumper($value)."\n" if $self->{debug};

    return $value > 0 ? $value : 0;
}

sub grid_counter
{
    my($self) = @_;
    my $value = shift $self->readAddress(JNX::SMAReader::TOTAL_GRID_COUNTER);

    print STDERR "grid_counter: :".Data::Dumper->Dumper($value)."\n" if $self->{debug};

    return $value > 0 ? $value : 0;
}



1;

