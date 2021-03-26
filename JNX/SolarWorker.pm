#!/usr/bin/perl
use strict;
use utf8;
use POSIX;

use Time::HiRes qw(usleep);
use Data::Dumper;
use JNX::JLog;

package JNX::SolarWorker::History;
use constant time => 'time';
use constant generation_counter => 'generation_counter';
use constant feedin_counter => 'feedin_counter';
use constant grid_counter => 'grid_counter';
use constant charge_counter => 'charge_counter';

package JNX::SolarWorker::Average;
use constant time => 'time';
use constant generation => 'generation';
use constant feedin => 'feedin';
use constant gridusage => 'gridusage';
use constant chargepower => 'chargepower';

package JNX::SolarWorker::Solar;
use constant generation => 'generation';
use constant limitation => 'limitation';
use constant feedin => 'feedin';
use constant gridusage => 'gridusage';
use constant voltage => 'voltage';
use constant stringapower => 'stringa';
use constant stringbpower => 'stringb';
use constant dailyyield => 'dailyyield';
use constant temperature => 'temperature';

use constant feedin_counter => 'feedin_counter';
use constant grid_counter => 'grid_counter';
use constant generation_counter => 'generation_counter';
1;
package JNX::SolarWorker::Charger;
use constant automode => 'automode';
use constant connected => 'connected';
use constant ischarging => 'ischarging';
use constant amperage => 'amperage';
1;
package JNX::SolarWorker::Car;
use constant decently_charged => 'decently_charged';
use constant fully_charged => 'fully_charged';
use constant soc => 'soc';
use constant chargelimit => 'chargelimit';
use constant pvchargelimit => 'pvchargelimit';
use constant carname => 'carname';
1;
package JNX::SolarWorker::Derived;
use constant chargepower => 'chargepower';
use constant housespare => 'housespare';
use constant houseconsumption => 'houseconsumption';
1;
package JNX::SolarWorker::Action;
use constant shouldcharge => 'shouldcharge';
use constant amperage => 'amperage';
use constant nextchange => 'nextchange';
use constant nextchange_string => 'nextchange_string';
use constant lastchange_string => 'lastchange_string';

package JNX::SolarWorker::Settings;
use constant chargetype => 'chargetype';
use constant chargelimit => 'chargelimit';
use constant solarsafety => 'solarsafety';
use constant chargespeed => 'chargespeed';

package JNX::SolarWorker::Status;
use constant Settings => 'settings';
use constant Action => 'action';
use constant Derived => 'derived';
use constant Charger => 'charger';
use constant Solar => 'solar';
use constant Car => 'car';

use constant time => 'time';
use constant timestring => 'timestring';
use constant runtime => 'runtime';
use constant timestring => 'timestring';
use constant Average => 'average';

package JNX::SolarWorker::SelfKey;
use constant debug => 'debug';
use constant historyarrayref => 'historyarrayref';
use constant feedinlimit => 'feedinlimit';
use constant historysize => 'historysize';
use constant minimumchargecurrent => 'minimumchargecurrent';
use constant maximumchargecurrent => 'maximumchargecurrent';
use constant settingsfilename => 'settingsfilename';


use constant starttime => 'starttime';
use constant settings => 'settings';
use constant action => 'action';
use constant pvReader => 'pvReader';
use constant evCharger => 'evCharger';
use constant carConnectors => 'carConnectors';
use constant carConnector => 'carConnector';
use constant decently_charged => 'decently_charged';
use constant fully_charged => 'fully_charged';
use constant chargecounter => 'chargecounter';
use constant Status => 'status';
1;

package JNX::SolarWorker::WebSettings;
use constant chargetype => 'settings.chargetype';
use constant chargelimit => 'settings.chargelimit';
use constant chargespeed => 'settings.chargespeed';
use constant solarsafety => 'settings.solarsafety';
1;

package JNX::SolarWorker::ChargeType;
use constant immediate => 'immediate';
use constant solar => 'solar';
1;

package JNX::SolarWorker::Options;

use constant debug => 'debug';
use constant historysize => 'historysize';
use constant minimumchargecurrent => 'minimumchargecurrent';
use constant maximumchargecurrent => 'maximumchargecurrent';
use constant feedinlimit => 'feedinlimit';
use constant settingsfilename => 'settingsfilename';

use constant pvReader       => 'pvReader';
use constant evCharger      => 'evCharger';
use constant carConnector   => 'carConnector';
use constant carConnectors  => 'carConnectors';

use constant chargetype     => 'chargetype';
use constant chargelimit    => 'chargelimit';
use constant chargespeed    => 'chargespeed';
use constant solarsafety    => 'solarsafety';
1;

package JNX::SolarWorker;
use JNX::SMAReader;
use JNX::PhoenixCharger;
use JNX::BMWConnector;
use Storable;
use JNX::Configuration;


my %commandlineoption = JNX::Configuration::newFromDefaults(
                                                                JNX::SolarWorker::Options::minimumchargecurrent => [6,'number'],
                                                                JNX::SolarWorker::Options::maximumchargecurrent => [20,'number'],
                                                                JNX::SolarWorker::Options::feedinlimit          => [6300*0.65 ,'number'],
                                                                JNX::SolarWorker::Options::historysize          => [10,'number'],
                                                                JNX::SolarWorker::Options::settingsfilename     => ['.solarworker.settings','string'],
                                                            );

sub new
{
    my ($class,%options) = (@_);

    my $self = {};
    bless $self, $class;
    JNX::JLog::debug "Options:".Data::Dumper->Dumper(\%options);

    $self->{JNX::SolarWorker::SelfKey::debug}                 = $options{JNX::SolarWorker::Options::debug}                 || $commandlineoption{JNX::SolarWorker::Options::debug};

    $self->{JNX::SolarWorker::SelfKey::minimumchargecurrent}  = $options{JNX::SolarWorker::Options::minimumchargecurrent}  || $commandlineoption{JNX::SolarWorker::Options::minimumchargecurrent};
    $self->{JNX::SolarWorker::SelfKey::maximumchargecurrent}  = $options{JNX::SolarWorker::Options::maximumchargecurrent}  || $commandlineoption{JNX::SolarWorker::Options::maximumchargecurrent};
    $self->{JNX::SolarWorker::SelfKey::feedinlimit}           = $options{JNX::SolarWorker::Options::feedinlimit}           || $commandlineoption{JNX::SolarWorker::Options::feedinlimit};
    $self->{JNX::SolarWorker::SelfKey::historysize}           = $options{JNX::SolarWorker::Options::historysize}           || $commandlineoption{JNX::SolarWorker::Options::historysize};
    $self->{JNX::SolarWorker::SelfKey::settingsfilename}      = $options{JNX::SolarWorker::Options::settingsfilename}      || $commandlineoption{JNX::SolarWorker::Options::settingsfilename};

    $self->{JNX::SolarWorker::SelfKey::pvReader}              = $options{JNX::SolarWorker::Options::pvReader}      || Carp::croak "Missing JNX::SolarWorker::Options::pvReader";
    $self->{JNX::SolarWorker::SelfKey::evCharger}             = $options{JNX::SolarWorker::Options::evCharger}     || Carp::croak "Missing JNX::SolarWorker::Options::evCharger";
    $self->{JNX::SolarWorker::SelfKey::carConnectors}         = $options{JNX::SolarWorker::Options::carConnectors} || Carp::croak "Missing JNX::SolarWorker::Options::carConnectors";
    $self->{JNX::SolarWorker::SelfKey::carConnector}          = @{$self->{JNX::SolarWorker::SelfKey::carConnectors}}[0];

    my %storedsettings;
    my $retrievedsettings = eval { retrieve( $self->{JNX::SolarWorker::SelfKey::settingsfilename} ) };

    %storedsettings = %{$retrievedsettings} if ref($retrievedsettings) eq 'HASH';
    JNX::JLog::debug "Stored settings:".Data::Dumper->Dumper(\%storedsettings);

    $self->{JNX::SolarWorker::SelfKey::settings} = {
            JNX::SolarWorker::Settings::chargetype  => ( $options{JNX::SolarWorker::Options::chargetype}   || $storedsettings{JNX::SolarWorker::Settings::chargetype}  || JNX::SolarWorker::ChargeType::solar ),
            JNX::SolarWorker::Settings::chargelimit => ( $options{JNX::SolarWorker::Options::chargelimit}  || $storedsettings{JNX::SolarWorker::Settings::chargelimit} || 80 ),
            JNX::SolarWorker::Settings::solarsafety => ( $options{JNX::SolarWorker::Options::solarsafety}  || $storedsettings{JNX::SolarWorker::Settings::solarsafety} || 200 ),
            JNX::SolarWorker::Settings::chargespeed => ( $options{JNX::SolarWorker::Options::chargespeed}  || $storedsettings{JNX::SolarWorker::Settings::chargespeed} || 20 ) ,
        };
    JNX::JLog::debug "Evaluated settings:".Data::Dumper->Dumper($self->{JNX::SolarWorker::SelfKey::settings} );

    for my $carconnector ( @{$self->{JNX::SolarWorker::SelfKey::carConnectors}} )
    {
        $carconnector->{JNX::SolarWorker::Car::chargelimit} = $self->{JNX::SolarWorker::SelfKey::settings}{JNX::SolarWorker::Settings::chargelimit};
    }

    $self->{JNX::SolarWorker::SelfKey::starttime}  = time();
    $self->{JNX::SolarWorker::SelfKey::action}     =  {
                                        JNX::SolarWorker::Action::shouldcharge    => 0,
                                        JNX::SolarWorker::Action::amperage        => 0,
                                        JNX::SolarWorker::Action::nextchange      => 0,
                                        JNX::SolarWorker::Action::nextchange_string => '',
                                        JNX::SolarWorker::Action::lastchange_string => 'never',
                                    };

    $self->{JNX::SolarWorker::SelfKey::historyarrayref} = [];
    $self->{JNX::SolarWorker::SelfKey::chargecounter} = 0;
    return $self;
}



sub readSolarValues
{
    my ($self) = (@_);

    my $pvReader = $self->{JNX::SolarWorker::SelfKey::pvReader};

    my $solar =  {
                    JNX::SolarWorker::Solar::generation           => $pvReader->current_generation(),
                    JNX::SolarWorker::Solar::limitation           => $pvReader->power_limititation(),
                    JNX::SolarWorker::Solar::feedin               => $pvReader->current_feedin(),
                    JNX::SolarWorker::Solar::gridusage            => $pvReader->current_gridusage(),
                    JNX::SolarWorker::Solar::voltage              => $pvReader->current_gridvoltage(),
                    JNX::SolarWorker::Solar::stringapower         => $pvReader->current_stringa_power(),
                    JNX::SolarWorker::Solar::stringbpower         => $pvReader->current_stringb_power(),
                    JNX::SolarWorker::Solar::feedin_counter       => $pvReader->feedin_counter() * 3600,
                    JNX::SolarWorker::Solar::grid_counter         => $pvReader->grid_counter() * 3600,
                    JNX::SolarWorker::Solar::generation_counter   => $pvReader->generation_counter() * 3600,
                    JNX::SolarWorker::Solar::dailyyield           => $pvReader->dailyyield(),
                    JNX::SolarWorker::Solar::temperature          => $pvReader->temperature(),
                };
    JNX::JLog::debug 'solar:'.Data::Dumper->Dumper($solar);
    return $solar;
}



sub readChargerValues
{
    my ($self) = (@_);

    my $evCharger = $self->{JNX::SolarWorker::SelfKey::evCharger};

    my $charger  = {    JNX::SolarWorker::Charger::automode   => $evCharger->automatic_charging_enabled(),
                        JNX::SolarWorker::Charger::connected  => $evCharger->car_is_connected(),
                        JNX::SolarWorker::Charger::ischarging => $evCharger->car_is_charging(),
                        JNX::SolarWorker::Charger::amperage   => $evCharger->current_charge_current(),
                    };

    JNX::JLog::debug 'charger:'.Data::Dumper->Dumper($charger);
    return $charger;
}



sub readCarValues
{
    my ($self,$chargerisconnected) = (@_);
    my $car;

    JNX::JLog::debug("testing which car is connected, charger is connected:$chargerisconnected");

    my $carConnector = $self->{JNX::SolarWorker::SelfKey::carConnector};
    
    if( !$chargerisconnected )
    { 
        $carConnector = undef;
    }
    else
    {
        TESTCARS: for my $testCar ( @{$self->{JNX::SolarWorker::SelfKey::carConnectors}} )
        {
            JNX::JLog::debug("testing car:".$testCar->carName().'athome:'.$testCar->isAtHome().'connected:'.$testCar->isConnected());

            if( $testCar->isAtHome() && $testCar->isConnected() )
            {
                JNX::JLog::debug("car is connected:".$testCar->carName());

                $self->{JNX::SolarWorker::SelfKey::carConnector} = $testCar;

                $carConnector = $self->{JNX::SolarWorker::SelfKey::carConnector};
                $carConnector->{JNX::SolarWorker::Car::chargelimit} = $self->{JNX::SolarWorker::SelfKey::settings}{JNX::SolarWorker::Settings::chargelimit};

                last TESTCARS;
            }
        }
    }

    if( !$carConnector || !$chargerisconnected )
    {
    	JNX::JLog::debug("no car is connected");

        $self->{JNX::SolarWorker::SelfKey::decently_charged}   = 0;
        $self->{JNX::SolarWorker::SelfKey::fully_charged}      = 0;
        $$car{JNX::SolarWorker::Car::carname}                  = 'Unknown';
        $$car{JNX::SolarWorker::Car::soc} =  0;
    }
    else
    {
        $self->{JNX::SolarWorker::SelfKey::decently_charged}  = $carConnector->hasReachedChargeLimitAtHome()      || $self->{JNX::SolarWorker::SelfKey::decently_charged};
        $self->{JNX::SolarWorker::SelfKey::fully_charged}     = $carConnector->hasReachedPVLimitAtHome()          || $self->{JNX::SolarWorker::SelfKey::fully_charged};
        $$car{JNX::SolarWorker::Car::carname}                 = $carConnector->carName();
        $$car{JNX::SolarWorker::Car::soc}                     = $carConnector->currentStateOfCharge();
   }
    $$car{JNX::SolarWorker::Car::decently_charged}    =  $self->{JNX::SolarWorker::SelfKey::decently_charged};
    $$car{JNX::SolarWorker::Car::fully_charged}       =  $self->{JNX::SolarWorker::SelfKey::fully_charged};

    $$car{JNX::SolarWorker::Car::chargelimit}         =  $carConnector->{chargelimit} || $self->{JNX::SolarWorker::SelfKey::settings}{JNX::SolarWorker::Settings::chargelimit};
    $$car{JNX::SolarWorker::Car::pvchargelimit}       =  $carConnector->{pvchargelimit};

    JNX::JLog::debug 'car:'.Data::Dumper->Dumper($car);

    return $car;
}



sub generateHistoryAndAverage
{
    my ($self,$timenow,$solar,$derived) = (@_);

    {
        my $lasttimerun         = $self->{JNX::SolarWorker::SelfKey::Status}{JNX::SolarWorker::Status::time};
        my $timesincelastloop   = $lasttimerun ? $timenow - $lasttimerun : 0;

        $self->{JNX::SolarWorker::SelfKey::chargecounter} = $self->{JNX::SolarWorker::SelfKey::chargecounter} + ( $$derived{JNX::SolarWorker::Derived::chargepower} * $timesincelastloop );
    }

    my $average;

    my $current_usage   = {     JNX::SolarWorker::History::time                => $timenow,
                                JNX::SolarWorker::History::generation_counter  => $$solar{JNX::SolarWorker::Solar::generation_counter},
                                JNX::SolarWorker::History::feedin_counter      => $$solar{JNX::SolarWorker::Solar::feedin_counter},
                                JNX::SolarWorker::History::grid_counter        => $$solar{JNX::SolarWorker::Solar::grid_counter},
                                JNX::SolarWorker::History::charge_counter      => $self->{JNX::SolarWorker::SelfKey::chargecounter},
                          };
    JNX::JLog::debug 'current_usage'.Data::Dumper->Dumper($current_usage);

    #######
    # history
    #######

    my $historyarrayref = $self->{JNX::SolarWorker::SelfKey::historyarrayref};
    push(@{$historyarrayref},$current_usage);

    if( @{$historyarrayref} > 1 )
    {
        my $previous_usage  =  @{$historyarrayref}[0];

        my $history_time = $$current_usage{JNX::SolarWorker::History::time} - $$previous_usage{JNX::SolarWorker::History::time};

        if( $history_time > 0)
        {
            $average =  {
                            JNX::SolarWorker::Average::time           =>  $history_time,
                            JNX::SolarWorker::Average::generation     =>  int( ($$current_usage{JNX::SolarWorker::History::generation_counter}  - $$previous_usage{JNX::SolarWorker::History::generation_counter} ) / $history_time ),
                            JNX::SolarWorker::Average::feedin         =>  int( ($$current_usage{JNX::SolarWorker::History::feedin_counter}      - $$previous_usage{JNX::SolarWorker::History::feedin_counter}     ) / $history_time ),
                            JNX::SolarWorker::Average::gridusage      =>  int( ($$current_usage{JNX::SolarWorker::History::grid_counter}        - $$previous_usage{JNX::SolarWorker::History::grid_counter}       ) / $history_time ),
                            JNX::SolarWorker::Average::chargepower    =>  int( ($$current_usage{JNX::SolarWorker::History::charge_counter}      - $$previous_usage{JNX::SolarWorker::History::charge_counter}     ) / $history_time ),
                        };
        }

        if( @{$historyarrayref} > $self->{JNX::SolarWorker::SelfKey::historysize} )
        {
            shift @{$historyarrayref};
        }
    }
    else
    {
        $average =  {
                        JNX::SolarWorker::Average::time           =>  0,
                        JNX::SolarWorker::Average::generation     =>  $$solar{JNX::SolarWorker::Solar::generation},
                        JNX::SolarWorker::Average::feedin         =>  $$solar{JNX::SolarWorker::Solar::feedin},
                        JNX::SolarWorker::Average::gridusage      =>  $$solar{JNX::SolarWorker::Solar::gridusage},
                        JNX::SolarWorker::Average::chargepower    =>  $$derived{JNX::SolarWorker::Derived::chargepower},
                    };
    }

    JNX::JLog::debug 'history:'.Data::Dumper->Dumper($historyarrayref);
    JNX::JLog::debug 'average:'.Data::Dumper->Dumper($average);
    return $average;
}



sub generateDerivedValues
{
    my ($self,$solar,$charger) = (@_);

    my $derived;
    $$derived{JNX::SolarWorker::Derived::chargepower}      =  ($$charger{JNX::SolarWorker::Charger::ischarging} && $$charger{JNX::SolarWorker::Charger::connected} ) ? int( $$solar{JNX::SolarWorker::Solar::voltage} * $$charger{JNX::SolarWorker::Charger::amperage} ) : 0;
    $$derived{JNX::SolarWorker::Derived::houseconsumption} =  int( $$solar{JNX::SolarWorker::Solar::generation} - $$solar{JNX::SolarWorker::Solar::feedin} + $$solar{JNX::SolarWorker::Solar::gridusage} - $$derived{JNX::SolarWorker::Derived::chargepower} );
    $$derived{JNX::SolarWorker::Derived::housespare}       =  int( $$solar{JNX::SolarWorker::Solar::feedin}     - $$solar{JNX::SolarWorker::Solar::gridusage} + $$derived{JNX::SolarWorker::Derived::chargepower} );

    JNX::JLog::debug 'derived:'.Data::Dumper->Dumper($derived);
    return $derived;
}

sub generateAction
{
    my($self,$timenow,$carvalues,$solarvalues,$chargevalues,$derivedvalues) = @_;

    my $charger_shouldcharge = $$chargevalues{JNX::SolarWorker::Charger::ischarging};
    my $charger_amperage     = $$chargevalues{JNX::SolarWorker::Charger::amperage};

    if( !$$chargevalues{JNX::SolarWorker::Charger::automode} )                      # if button is pressed set to maximumcharge immediate
    {
        $charger_shouldcharge = 1;
        $charger_amperage     = $self->{JNX::SolarWorker::SelfKey::maximumchargecurrent};
    }
    else
    {
        if( $timenow > $self->{JNX::SolarWorker::SelfKey::action}{JNX::SolarWorker::Action::nextchange} )
        {
            JNX::JLog::debug "Testing for required charge change";

            my $minimumchargecurrent = $self->{JNX::SolarWorker::SelfKey::minimumchargecurrent};
            my $maximumchargecurrent = $self->{JNX::SolarWorker::SelfKey::maximumchargecurrent};
            JNX::JLog::trace "minimumchargecurrent:$minimumchargecurrent maximumchargecurrent:$maximumchargecurrent";

            if( JNX::SolarWorker::ChargeType::immediate eq $self->{JNX::SolarWorker::SelfKey::settings}{JNX::SolarWorker::Settings::chargetype} )
            {
                $charger_shouldcharge = 1;
                $charger_amperage     = clamp($self->{JNX::SolarWorker::SelfKey::settings}{JNX::SolarWorker::Settings::chargespeed},$minimumchargecurrent,$maximumchargecurrent);
            }
            else
            {
                my $chargeonfeedin  = -1 == $self->{JNX::SolarWorker::SelfKey::settings}{JNX::SolarWorker::Settings::solarsafety} ? 1 : 0;
                my $solarsafety     = maximum($self->{JNX::SolarWorker::SelfKey::settings}{JNX::SolarWorker::Settings::solarsafety},0);
                my $housespare      = $$derivedvalues{JNX::SolarWorker::Derived::housespare};
                my $spareamperage   = int( ($housespare - $solarsafety) / $$solarvalues{JNX::SolarWorker::Solar::voltage} );

                JNX::JLog::debug "chargeonfeedin:$chargeonfeedin solarsafety:$solarsafety housespare:$housespare, spareamperage:$spareamperage";

                if( $housespare > 0)
                {
                    if( $chargeonfeedin )
                    {
                        $charger_shouldcharge = 1;
                        $charger_amperage = clamp($spareamperage,$minimumchargecurrent,$maximumchargecurrent);
                        JNX::JLog::trace "charger_amperage: $charger_amperage minimumchargecurrent:$minimumchargecurrent maximumchargecurrent:$maximumchargecurrent";
                    }
                    elsif( $spareamperage >= $minimumchargecurrent )
                    {
                        $charger_shouldcharge = 1;

                        if( (0==$solarsafety) && ($spareamperage > $minimumchargecurrent) )
                        {
                            $spareamperage = $spareamperage - 1;
                        }
                        $charger_amperage = minimum($spareamperage,$maximumchargecurrent);
                    }
                    else
                    {
                        $charger_shouldcharge = 0;
                    }
                }
                else
                {
                    $charger_shouldcharge = 0;
                }
            }

            if( $charger_shouldcharge )
            {
                if( !$$chargevalues{JNX::SolarWorker::Charger::connected} )
                {
                    JNX::JLog::debug "No Car connected - not charging";
                    $charger_shouldcharge = 0;
                }
                elsif( $self->{JNX::SolarWorker::SelfKey::fully_charged} )
                {
                    JNX::JLog::debug "Fully charged - not charging";
                    $charger_shouldcharge = 0;
                }
                elsif( $self->{JNX::SolarWorker::SelfKey::decently_charged} )
                {
                    my $startcharging = $self->{JNX::SolarWorker::Options::feedinlimit} - $$solarvalues{JNX::SolarWorker::Solar::voltage};
                    my $housespare    = $$derivedvalues{JNX::SolarWorker::Derived::housespare};

                    JNX::JLog::trace "decently charged: currentspare: $housespare startcharging: $startcharging feedinlimit:$self->{JNX::SolarWorker::Options::feedinlimit}";

                    if( $housespare > $startcharging )
                    {
                        my $spareamperage   = int( ($housespare - $startcharging ) / $$solarvalues{JNX::SolarWorker::Solar::voltage} );
                        $charger_amperage = clamp($spareamperage,$minimumchargecurrent,$maximumchargecurrent);
                        JNX::JLog::trace "decently charged: $spareamperage charger_amperage: $charger_amperage minimumchargecurrent:$minimumchargecurrent maximumchargecurrent:$maximumchargecurrent";
                    }
                    else
                    {
                        JNX::JLog::debug "decently charged: and no pv limit";
                        $charger_shouldcharge = 0;
                    }
                }
            }
        }
        else
        {
            JNX::JLog::debug "Next change date not reached";
        }
    }


    if(     ($$chargevalues{JNX::SolarWorker::Charger::ischarging} != $charger_shouldcharge)
        ||  ($charger_shouldcharge && ($$chargevalues{JNX::SolarWorker::Charger::amperage} != $charger_amperage) )
      )
    {
        JNX::JLog::info 'Change Charging: '.Data::Dumper->Dumper( $self->{action} );

        my $evCharger = $self->{JNX::SolarWorker::SelfKey::evCharger};


        if( $$chargevalues{JNX::SolarWorker::Charger::ischarging} != $charger_shouldcharge )
        {
            JNX::JLog::debug 'chargestate differs -> charger_shouldcharge:'.$charger_shouldcharge;
            $evCharger->set_charging_enabled($charger_shouldcharge);
        }

        if(    ( $charger_amperage >= $self->{JNX::SolarWorker::SelfKey::minimumchargecurrent} )
            && ( $$chargevalues{JNX::SolarWorker::Charger::amperage} != $charger_amperage )
          )
        {
            JNX::JLog::debug 'amperage differs -> charger_amperage:'.$charger_amperage;
            $evCharger->set_charge_current($charger_amperage);
        }


        my $timetowait = ($self->{JNX::SolarWorker::SelfKey::action}{JNX::SolarWorker::Action::shouldcharge} != $charger_shouldcharge) ? 300 : 120;

        my $action =    {
                            JNX::SolarWorker::Action::shouldcharge        =>  $charger_shouldcharge,
                            JNX::SolarWorker::Action::amperage            =>  $charger_amperage,
                            JNX::SolarWorker::Action::nextchange          =>  $timenow + $timetowait,
                            JNX::SolarWorker::Action::nextchange_string   =>  isotime($timenow + $timetowait),
                            JNX::SolarWorker::Action::lastchange_string   =>  isotime($timenow),
                        };
        JNX::JLog::debug 'action:'.Data::Dumper->Dumper($action);
        $self->{JNX::SolarWorker::SelfKey::action} = $action;
    }

    return $self->{JNX::SolarWorker::SelfKey::action};
}


sub workloop
{
    my ($self) = (@_);
    JNX::JLog::debug;

    my $timenow             = time;

    my $solarvalues     = $self->readSolarValues();
    my $chargevalues    = $self->readChargerValues();
    my $carvalues       = $self->readCarValues( $$chargevalues{JNX::SolarWorker::Charger::connected} );

    my $derivedvalues   = $self->generateDerivedValues($solarvalues,$chargevalues);
    my $averagevalues   = $self->generateHistoryAndAverage($timenow,$solarvalues,$derivedvalues);

    my $actionvalues    = $self->generateAction($timenow,$carvalues,$solarvalues,$chargevalues,$derivedvalues);


    my $current_status  =   {
                                JNX::SolarWorker::Status::time          => $timenow,
                                JNX::SolarWorker::Status::timestring    => isotime($timenow),
                                JNX::SolarWorker::Status::runtime       => runtime($timenow - $self->{JNX::SolarWorker::SelfKey::starttime}),

                                JNX::SolarWorker::Status::Solar         => $solarvalues,
                                JNX::SolarWorker::Status::Charger       => $chargevalues,
                                JNX::SolarWorker::Status::Car           => $carvalues,
                                JNX::SolarWorker::Status::Derived       => $derivedvalues,
                                JNX::SolarWorker::Status::Average       => $averagevalues,
                                JNX::SolarWorker::Status::Action        => $actionvalues,
                            };


    $self->{JNX::SolarWorker::SelfKey::Status} = $current_status;

    JNX::JLog::info 'status:'.Data::Dumper->Dumper($self->{JNX::SolarWorker::SelfKey::Status});
    JNX::JLog::info 'settings:'.Data::Dumper->Dumper($self->{JNX::SolarWorker::SelfKey::settings});
}


sub command
{
    my ($self,$input) = @_;

    JNX::JLog::debug if $self->{JNX::SolarWorker::SelfKey::debug};

    my $settingschanged = 0;
    
    if( ref($input) eq 'HASH' )
    {
        my $matchstring = JNX::SolarWorker::ChargeType::solar .'|'. JNX::SolarWorker::ChargeType::immediate;

        if( $$input{JNX::SolarWorker::WebSettings::chargetype} =~ m/^($matchstring)$/o )
        {
            $self->{JNX::SolarWorker::SelfKey::settings}{JNX::SolarWorker::Settings::chargetype} = $$input{JNX::SolarWorker::WebSettings::chargetype};
            $settingschanged = 1;
        }
        if( $$input{JNX::SolarWorker::WebSettings::chargelimit} =~ m/^(\d+)$/o )
        {
            $self->{JNX::SolarWorker::SelfKey::settings}{JNX::SolarWorker::Car::chargelimit}        = $$input{JNX::SolarWorker::WebSettings::chargelimit};
            $self->{JNX::SolarWorker::SelfKey::carConnector}->{JNX::SolarWorker::Car::chargelimit}  = $$input{JNX::SolarWorker::WebSettings::chargelimit};
            $self->{JNX::SolarWorker::SelfKey::decently_charged} = 0;
            $settingschanged = 1;
        }
        if( $$input{JNX::SolarWorker::WebSettings::chargespeed} =~ m/^(\d+)$/o )
        {
            $self->{JNX::SolarWorker::SelfKey::settings}{JNX::SolarWorker::Settings::chargespeed} = $$input{JNX::SolarWorker::WebSettings::chargespeed};
            $settingschanged = 1;
        }
        if( $$input{JNX::SolarWorker::WebSettings::solarsafety} =~ m/^(\-1|\d+)$/o )
        {
            $self->{JNX::SolarWorker::SelfKey::settings}{JNX::SolarWorker::Settings::solarsafety} = $$input{JNX::SolarWorker::WebSettings::solarsafety};
            $settingschanged = 1;
        }
    }

    my %settings = %{$self->{JNX::SolarWorker::SelfKey::settings}};

    if( $settingschanged )
    {
        store \%settings, ($self->{JNX::SolarWorker::SelfKey::settingsfilename}) || JNX::JLog::error "Can't safe settings due to:$!";
    }

    delete $settings{JNX::SolarWorker::Settings::solarsafety} if $self->{JNX::SolarWorker::SelfKey::settings}{JNX::SolarWorker::Settings::chargetype} eq JNX::SolarWorker::ChargeType::immediate;
    delete $settings{JNX::SolarWorker::Settings::chargespeed} if $self->{JNX::SolarWorker::SelfKey::settings}{JNX::SolarWorker::Settings::chargetype} eq JNX::SolarWorker::ChargeType::solar;


    return {
                status      => $self->{JNX::SolarWorker::SelfKey::Status},
                settings    => \%settings,
            }
}


#helper functions

sub isotime
{
    my ($now) = (@_);
    $now = $now || Time::HiRes::time();

    my $subseconds = substr(sprintf("%.3f",($now-int($now))),1);
    return POSIX::strftime('%H:%M:%S%z', localtime($now));
}
sub runtime
{
    my ($seconds) = (@_);

    sprintf("%0dd %02d:%02d:%02d",int($seconds/86400),int(($seconds%86400)/3600),int(($seconds%3600)/60),int($seconds%60));
}
sub maximum
{
    my($a,$b) = @_;

    return $a > $b ? $a : $b;
}
sub minimum
{
    my($a,$b) = @_;

    return $a < $b ? $a : $b;
}

sub clamp
{
    my($a,$low,$high) = @_;

    return $a < $low ? $low : ( $a > $high ? $high : $a );
}


1;
