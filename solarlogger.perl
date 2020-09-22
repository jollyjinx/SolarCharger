#!/usr/bin/perl
use strict;
use FindBin; use lib "$FindBin::Bin/perl5/lib/perl5","$FindBin::Bin/JNX","$FindBin::Bin";

use JNX::Configuration;
use JNX::SMAReader;

my %commandlineoption = JNX::Configuration::newFromDefaults(
                                                                'looptime'      => [ 1,'number'],
                                                            );

my  $pvReader    = JNX::SMAReader->new() || die "Could not create smareader";

while(1)
{
    #$pvReader->sleepReading($commandlineoption{'looptime'});
    $pvReader->showLoop($commandlineoption{'looptime'});
    $pvReader->showLoopLine();
}

