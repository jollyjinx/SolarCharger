#!/usr/bin/perl

use strict;
use JNX::ModbusDevice;
use Time::HiRes;
use POSIX;
use Data::Dumper;
use JNX::Configuration;
use JNX::JLog;
use utf8;

package JNX::SMAReader;
use parent 'JNX::ModbusDevice';

use constant DEVICE_TYPE_ID             => 30051; # 0x7563
use constant DEVICE_TYPE_SOLAR_ID       =>  8001; # 0x1F41
use constant DEVICE_TYPE_SOLAR          => 'solar';
use constant DEVICE_TYPE_BATTERY        => 'battery';

use constant POWER_LIMITATION           => 40212; # 0x9D14
use constant CURRENT_GENERATION         => 30775; # 0x7837
use constant GRID_CURRENT_PHASE_A       => 31253; # 0x7A15
use constant CURRENT_FEEDIN             => 30867; # 0x7893
use constant CURRENT_GRID_USAGE         => 30865; # 0x7891
use constant TOTAL_YIELD_COUNTER        => 30513; # 0x7731
use constant TOTAL_FEEDIN_COUNTER       => 30583; # 0x7777
use constant TOTAL_GRID_COUNTER         => 30581; # 0x7775
use constant DAILY_YIELD                => 30517; # 0x7735    // 30535;
use constant TEMPERATURE                => 34113; # 0x8541
use constant CURRENT_STRINGA_POWER      => 30773; # 0x7835
use constant CURRENT_STRINGB_POWER      => 30961; # 0x78F1


my %commandlineoption = JNX::Configuration::newFromDefaults(
                                                                'SMAAddress'    => [undef,'string'],
                                                                'SMAName'       => ['sunnyboy','string'],
                                                            );
sub new
{
    my ($class,%options) = (@_);

    $options{host}                  = $commandlineoption{'SMAAddress'}  || die "No SMAAddress set";
    $options{devicename}            = $commandlineoption{'SMAName'}     || die "No SMAName set";
    $options{debug}                 = $commandlineoption{'debug'};

    $options{id}                    = 3;
    $options{maximum_backgroundsize}= $options{maximum_backgroundsize} || 1000;

    $options{inputregisters} = {

        JNX::SMAReader::DEVICE_TYPE_ID          => {valuetype => 'UInt32',    modbustype => 'register', access=>'r', loop => 0, devicetype => 'all',    name => 'deviceclass',  unit => 'string',               description => 'Device class'           },
        30213                                   => {valuetype => 'UInt32',    modbustype => 'register', access=>'r', loop => 0, devicetype => 'all',    name => 'currenterror', unit => 'string',               description => 'Current Error (886=no message)' },
        30053                                   => {valuetype => 'UInt32',    modbustype => 'register', access=>'r', loop => 0, devicetype => 'all',    name => 'devicetype',   unit => 'string',               description => 'Device type'           },
        30057                                   => {valuetype => 'UInt32',    modbustype => 'register', access=>'r', loop => 0, devicetype => 'all',    name => 'serialnumber', unit => 'int',                  description => 'Serial number'         },
        30929                                   => {valuetype => 'UInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'all',    name => 'speedwirestate', unit => 'int',                description => 'Speedwire connection State (307:Ok)'         },
        40157                                   => {valuetype => 'UInt32',    modbustype => 'register', access=>'r', loop => 0, devicetype => 'all',    name => 'speedwiresautoconfig', unit => 'int',          description => 'Speedwire autoconfiguration (1129:yes)' },
        40631   => {modbussize => 8,wordcount => 12,valuetype => 'ascii',     modbustype => 'register', access=>'r', loop => 1, devicetype => 'all',    name => 'name',         unit => 'string',               description => 'Name'                  },
        40647                                   => {valuetype => 'UInt32',    modbustype => 'register', access=>'r', loop => 0, devicetype => 'all',    name => 'autoupdate',   unit => 'int',                  description => 'Automatic updates YES:1129 No:1130' },

        31405                                   => {valuetype => 'SInt32',    modbustype => 'register', access=>'r', loop => 0, devicetype => 'solar',  name => 'currentlimit', unit => 'W',                    description => 'Current Limitation'     },

        JNX::SMAReader::POWER_LIMITATION        => {valuetype => 'UInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'solar',  name => 'powerlimit',   unit => 'W',                    description => 'Power Limitation'     },
        30233                                   => {valuetype => 'UInt32',    modbustype => 'register', access=>'r', loop => 0, devicetype => 'solar',  name => 'activelimit',  unit => 'W',                    description => 'Active Limitation'     },
        30231                                   => {valuetype => 'UInt32',    modbustype => 'register', access=>'r', loop => 0, devicetype => 'solar',  name => 'maximumpower', unit => 'W',                    description => 'Maximum Power'     },
        30803                                   => {valuetype => 'UInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'all',    name => 'gridfrequency',unit => 'Hz',   factor => 0.01, description => 'Grid frequency'      },
        JNX::SMAReader::GRID_CURRENT_PHASE_A    => {valuetype => 'UInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'solar',  name => 'voltagea',     unit => 'V',    factor => 0.01, description => 'Voltage Phase A'},
        31255                                   => {valuetype => 'UInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'solar',  name => 'voltageb',     unit => 'V',    factor => 0.01, description => 'Voltage Phase B'},
        31257                                   => {valuetype => 'UInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'solar',  name => 'voltagec',     unit => 'V',    factor => 0.01, description => 'Voltage Phase C'},

        JNX::SMAReader::DAILY_YIELD             => {valuetype => 'UInt64',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'solar',  name => 'dailyyield',   unit => 'kWh', factor => 0.001, description => 'Daily yield'       },
        JNX::SMAReader::TOTAL_YIELD_COUNTER     => {valuetype => 'UInt64',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'solar',  name => 'totalyield',   unit => 'kWh', factor => 0.001, description => 'Total yield'       },

        JNX::SMAReader::TOTAL_GRID_COUNTER      => {valuetype => 'UInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'solar',  name => 'gridcounter',  unit => 'kWh', factor => 0.001, description => 'Grid Counter'     },
        JNX::SMAReader::TOTAL_FEEDIN_COUNTER    => {valuetype => 'UInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'solar',  name => 'feedincounter',unit => 'kWh', factor => 0.001, description => 'Feed in Counter'  },
        JNX::SMAReader::CURRENT_GENERATION      => {valuetype => 'SInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'solar',  name => 'power',        unit => 'W',                    description => 'AC Power'          },

        30571                                   => {valuetype => 'UInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'solar',   name => 'consumption', unit => 'W',                    description => 'Current self-consumption (W)'},

        JNX::SMAReader::CURRENT_STRINGA_POWER   => {valuetype => 'SInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'solar',  name => 'stringa',      unit => 'W',                    description => 'DC power1'},
        JNX::SMAReader::CURRENT_STRINGB_POWER   => {valuetype => 'SInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'solar',  name => 'stringb',      unit => 'W',                    description => 'DC power2'          },

        34109                                   => {valuetype => 'SInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'solar',  name => 'externaltemp', unit => '°C',   factor => 0.1,  description => 'Heat sink temp'     },
        JNX::SMAReader::TEMPERATURE             => {valuetype => 'SInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'all',    name => 'internaltemp', unit => '°C',   factor => 0.1,  description => 'Internal temp'      },

        JNX::SMAReader::CURRENT_FEEDIN          => {valuetype => 'SInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'all',    name => 'feedin',       unit => 'W',                    description => 'Feed in'            },
        JNX::SMAReader::CURRENT_GRID_USAGE      => {valuetype => 'SInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'all',    name => 'usage',        unit => 'W',                    description => 'Grid usage'         },

        31393                                   => {valuetype => 'UInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'battery',name => 'charge',           unit => 'W',                    description => 'Battery charge'        },
        31395                                   => {valuetype => 'UInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'battery',name => 'discharge',        unit => 'W',                    description => 'Battery discharge'     },
        30845                                   => {valuetype => 'UInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'battery',name => 'batterysoc',       unit => '%',                    description => 'Battery SoC'      },
        30849                                   => {valuetype => 'SInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'battery',name => 'batterytemp',      unit => '°C',  factor => 0.1,   description => 'Battery Temperature'      },
        30535                                   => {valuetype => 'UInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'battery',name => 'dailydischarge',   unit => 'kWh', factor => 0.001, description => 'Discharge Today'  },
#        30535                                   => {valuetype => 'UInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'battery',name => 'dailycharge',      unit => 'kWh', factor => 0.001, description => 'Charge Today'  },
        31401                                   => {valuetype => 'UInt64',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'battery',name => 'totaldischarge',   unit => 'kWh', factor => 0.001, description => 'Toatal Discharge'  },
        31397                                   => {valuetype => 'UInt64',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'battery',name => 'totalcharge',      unit => 'kWh', factor => 0.001, description => 'Toatal Charge'  },


#                                    34125 => {valuetype => 'SInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'all',     description => 'External temp(C)'      },
#                                    30517 => { modbussize => 64,  wordcount => 4, valuetype => 'UInt64',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'solar',   description => 'Daily yield(Wh)'       },

#                                    40016 => { modbussize => 16,  wordcount => 1, valuetype => 'SInt16',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'solar',   description => 'Power Limitation (W)'     },
#                                    30835 => {valuetype => 'UInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'solar',   description => '30835'     },
#                                    30837 => {valuetype => 'UInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'solar',   description => '30837'     },
#                                    30839 => {valuetype => 'UInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'solar',   description => '30839'     },
#                                    40015 => {valuetype => 'UInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'solar',   description => '40015'     },

#                                    30861 => {valuetype => 'SInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'all',   description => 'Load power (W)'          },
#                                    30863 => {valuetype => 'UInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'all',   description => 'Current PV array power (W)'          },
#                                    JNX::SMAReader::CURRENT_GRID_USAGE => {valuetype => 'SInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'all',   description => 'Power purchased electricity (W)'          },
#                                    JNX::SMAReader::CURRENT_FEEDIN => {valuetype => 'SInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'all',   description => 'Power grid feed-in (W)'          },
#                                    30869 => {valuetype => 'SInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'all',   description => 'Power PV generation (W)'          },
#                                    30871 => {valuetype => 'UInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'all',   description => 'Current self-consumption (W)'          },
#
#                                    30885 => {valuetype => 'UInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'all',   description => 'Power of external grid connection (W)'          },
#                                    30983 => {valuetype => 'UInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'all',   description => 'PV power (W)'          },
#
#                                    31091 => {valuetype => 'SInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'all',   description => '31091 (W)'          },
#                                    31121 => {valuetype => 'SInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'all',   description => '31121 (W)'          },
#                                    JNX::SMAReader::CURRENT_GENERATION => {valuetype => 'SInt32',    modbustype => 'register', access=>'r', loop => 1, devicetype => 'solar',   description => 'Power (W)'          },

                            };
    return $class->SUPER::new(%options);
}

sub currentType
{
    my($self) = @_;
    
    if( my $returnvalue = $self->readAddressFromCache(JNX::SMAReader::DEVICE_TYPE_ID) )
    {
        my $devicetype = $returnvalue == JNX::SMAReader::DEVICE_TYPE_SOLAR_ID  ? JNX::SMAReader::DEVICE_TYPE_SOLAR : JNX::SMAReader::DEVICE_TYPE_BATTERY;
    
        return $devicetype;
    }
    
    return undef;
}

sub sleepReading
{
    my($self,$sleeptime,$timeperstep) = @_;

    my $steptime = $timeperstep || 2;
    
   # JNX::JLog::debug "steptime:$steptime sleeptime:$sleeptime";
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

    
    JNX::JLog::debug "backgroundsize:".$backgroundsize;
    JNX::JLog::debug "backgroundsize:".Data::Dumper->Dumper($self->{backgoundData});
}



sub power_limititation
{
    my($self) = @_;
    
    my $value = $self->readAddress(JNX::SMAReader::POWER_LIMITATION);

    JNX::JLog::debug "powerlimititation: :".Data::Dumper->Dumper($value);

    return $value;
}



sub current_generation
{
    my($self) = @_;
    my $value = $self->readAddress(JNX::SMAReader::CURRENT_GENERATION);

    JNX::JLog::debug "current_generation: :".Data::Dumper->Dumper($value);

    return $value > 0 ? $value : 0;
}


sub current_stringa_power
{
    my($self) = @_;
    my $value = $self->readAddress(JNX::SMAReader::CURRENT_STRINGA_POWER);

    JNX::JLog::debug "current_stringa_power: :".Data::Dumper->Dumper($value);

#    if( $value < 0 || $value > 1000000000 ) { $value = 0 }
    return $value;
}

sub current_stringb_power
{
    my($self) = @_;
    my $value = $self->readAddress(JNX::SMAReader::CURRENT_STRINGB_POWER);

    JNX::JLog::debug "current_stringb_power: :".Data::Dumper->Dumper($value);

#    if( $value < 0 || $value > 1000000000 ) { $value = 0 }
    return $value;
}

sub current_gridvoltage
{
    my($self) = @_;
    my $value = $self->readAddress(JNX::SMAReader::GRID_CURRENT_PHASE_A);

    JNX::JLog::debug "current_gridvoltage: :".Data::Dumper->Dumper($value);

    return $value; # ($value > 20000) && ($value < 25000) ? $value/100 : 230;
}

sub dailyyield
{
    my($self) = @_;
    my $value = $self->readAddress(JNX::SMAReader::DAILY_YIELD);

    JNX::JLog::debug "daily yield: :".Data::Dumper->Dumper($value);

#    if( $value < 0 || $value > 1000000000 ) { $value = 0 }
#    $value = sprintf "%.1f",($value / 1000);
    return $value;
}

sub temperature
{
    my($self) = @_;
    my $value = $self->readAddress(JNX::SMAReader::TEMPERATURE);

    JNX::JLog::debug "temperature: :".Data::Dumper->Dumper($value);

 #   if( $value < -10000000 || $value > 1000000 ) { $value = 0 }
 #  $value = sprintf "%.1f",($value / 10);
    return $value;
}

sub current_feedin
{
    my($self) = @_;
    my $value = $self->readAddress(JNX::SMAReader::CURRENT_FEEDIN);

    JNX::JLog::debug "current_feedin: :".Data::Dumper->Dumper($value);

    return $value > 0 ? $value : 0;
}



sub current_gridusage
{
    my($self) = @_;
    my $value = $self->readAddress(JNX::SMAReader::CURRENT_GRID_USAGE);

    JNX::JLog::debug "current_gridusage: :".Data::Dumper->Dumper($value);

    return $value > 0 ? $value : 0;
}

sub generation_counter
{
    my($self) = @_;
    my $value = $self->readAddress(JNX::SMAReader::TOTAL_YIELD_COUNTER);

    JNX::JLog::debug "generation_counter: :".Data::Dumper->Dumper($value);

    return $value > 0 ? $value : 0;
}


sub feedin_counter
{
    my($self) = @_;
    my $value = $self->readAddress(JNX::SMAReader::TOTAL_FEEDIN_COUNTER);

    JNX::JLog::debug "feedin_counter: :".Data::Dumper->Dumper($value);

    return $value > 0 ? $value : 0;
}

sub grid_counter
{
    my($self) = @_;
    my $value = $self->readAddress(JNX::SMAReader::TOTAL_GRID_COUNTER);

    JNX::JLog::debug "grid_counter: :".Data::Dumper->Dumper($value);

    return $value > 0 ? $value : 0;
}



1;

