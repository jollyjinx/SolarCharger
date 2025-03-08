#!/usr/bin/perl

use strict;
use FindBin; use lib "$FindBin::Bin/perl5/lib/perl5","$FindBin::Bin","$FindBin::Bin/JNX";
use utf8;
use English;


use JNX::CarConnector;


my %commandlineoption = JNX::Configuration::newFromDefaults(
                                                            );

my $carConnector = JNX::CarConnector->new();

print "name:".$carConnector->carName()."\n";
print "connected:".$carConnector->isConnected()."\n";
print "ischarging:".$carConnector->isCharging()."\n";
print "soc:".$carConnector->currentStateOfCharge()."\n";
print "hasreachedchargelimitathome:".$carConnector->hasReachedChargeLimitAtHome()."\n";
print "hasreachedsolarchargelimit:".$carConnector->hasReachedPVLimitAtHome()."\n";
