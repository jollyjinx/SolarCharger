#!/usr/bin/perl
use strict;
use Time::HiRes qw(usleep);
use POSIX;
use Data::Dumper;
use MBclient;
use Carp;


package JNX::ModbusDevice;

sub isotime()
{
    my ($self,$now) = (@_);
    $now = $now || Time::HiRes::time();
    
    my $subseconds = substr(sprintf("%.3f",($now-int($now))),1);
    return sprintf "%s%s%s",''.POSIX::strftime('%Y-%m-%dT%H:%M:%S', localtime($now)),$subseconds,POSIX::strftime('%z', localtime($now)),
}

sub new
{
    my ($class,%options) = (@_);

    $options{host} || Carp::croak "Missing host";

    my $self = { %options };
     
    my $device = MBclient->new();
    
    $device->host($self->{host});
    $device->port($self->{port})    if defined $self->{port};
    $device->unit_id($self->{id})   if defined $self->{id};
    
    $self->{maximumconnecttime} = $options{maximumconnecttime} || (3600 * 3);
    $self->{device} = $device;
    $device->open() || Carp::croak "Can't open connection to host: ".$self->{host}."\n";
    $self->{connectionstarttime} = time();

    bless $self, $class;
    return $self;
}


sub reset
{
    print STDERR "JNX::ModbusDevice::reset called\n";
}

sub DESTROY
{
    my($self) = @_;
    
    $self->{device}->close();
    
    print STDERR "JNX::ModbusDevice::DESTROY called\n";
}

sub currentType
{
    return undef;
}


sub showAll
{
    my($self) = @_;
    
    my %inputregisters = %{$self->{inputregisters}};
    
    my $currenttype = $self->currentType() || 'all';
    
    for my $address (sort keys %inputregisters )
    {
        my $devicetype  = $inputregisters{$address}{devicetype};
        next if ( $devicetype ne 'all' && $devicetype ne $currenttype);

        my $values = $self->readAddress($address);
        
        printf "%40s %3d:",$inputregisters{$address}{name},$address;
        
        for my $value (@$values)
        {
            if( 'ascii' eq $inputregisters{$address}{contenttype} )
            {
                printf "%s", $value;
            }
            elsif( 'hex' eq $inputregisters{$address}{contenttype} )
            {
                printf "0x%04x ",$value;
            }
            elsif( 'bit' eq $inputregisters{$address}{contenttype} )
            {
                print "bits:";
                
                for my $bitnumber (0.. $inputregisters{$address}{modbussize}-1)
                {
                    my $valueBit = $value & (1 << $bitnumber);   # << $>>
                    
                    printf "\n\%45s bit[$bitnumber]:%d ",'',$valueBit > 0 ? 1:0;
                }
            }
            else
            {
                printf "%d ",$value;
            }
        }
        print "\n";
    }
}

sub loopAddresses
{
    my($self) = @_;
    
    my $loopAddresses = $self->{loopAddresses};
    return @{$loopAddresses} if $loopAddresses;
    
    my @loopAddresses   = ();
    my %inputregisters  = %{$self->{inputregisters}};
    my $currenttype     = $self->currentType() || 'all';
    
    for my $address (sort keys %inputregisters )
    {
        my $devicetype  = $inputregisters{$address}{devicetype};
        next if ( $devicetype ne 'all' && $devicetype ne $currenttype);

        push(@loopAddresses,$address) if $inputregisters{$address}{loop};
    }
    $self->{loopAddresses} = \@loopAddresses;
    
    return @loopAddresses;
}

sub showLoopHeader
{
    my($self) = @_;

    my %inputregisters = %{$self->{inputregisters}};

    print "\nDate/Time";
    for my $address ( $self->loopAddresses() )
    {
        print "\t".$inputregisters{$address}{name};
    }
    print "\n";
}

sub showLoopLine
{
    my($self) = @_;
    
    print $self->isotime();
    
    for my $address ( $self->loopAddresses() )
    {
        my $values = $self->readAddress($address);
    
        print "\t".join(':',@{$values});
    }
    print "\n";
}

sub showLoop
{
    my($self,$looptime) = @_;
    
    $self->showAll();
    $self->showLoopHeader();
    
    while(1)
    {
        $self->showLoopLine();
        sleep($looptime > 0 ? $looptime : 1 );
    }
}


sub readAddress
{
    my($self,$address) = @_;

    print STDERR "readAddress:$address\n" if $self->{debug};
    
    my $returnvalue = undef;
    
    if( my $register = $self->{inputregisters}{$address} )
    {
        print STDERR "readAddress:inputregister :".Data::Dumper->Dumper($register)."\n" if $self->{debug};

        $returnvalue = $self->readValuesFromModubus($address,$$register{modbustype},$$register{modbussize},$$register{wordcount},$$register{contenttype});
    }
    else
    {
        print STDERR "inputregister not known for address: $address\n";
    }
    
    $self->{cache}{$address}{time}  = time();
    $self->{cache}{$address}{value} = $returnvalue;
    
    return $returnvalue;
}


sub readAddressFromCache
{
    my($self,$address) = @_;

    print STDERR "readAddressFromCache:$address\n" if $self->{debug};
    
    return $self->{cache}{$address}{value} || $self->readAddress($address);
}



sub writeAddress
{
    my($self,$address,$newvalue) = @_;
    
    print STDERR "writeAddress:$address newvalue:$newvalue\n" if $self->{debug};


    my $returnvalue = undef;

    if( my $register = $self->{inputregisters}{$address} )
    {
        print STDERR "writeAddress:inputregister :".Data::Dumper->Dumper($register)."\n" if $self->{debug};
        
        my $modbusdevice    = $self->{device};
        my $modbustype      = $$register{modbustype};
        
        if( 'register' eq $modbustype )
        {
            return 1 if $modbusdevice->write_single_register($address,$newvalue);
        }
        elsif( 'discrete' eq $modbustype )
        {
            die "currently discrete write is not supported";
        }
        elsif( 'holding' eq $modbustype )
        {
            return 1 if $modbusdevice->write_single_register($address,$newvalue);
        }
        elsif( 'coil' eq $modbustype )
        {
            return 1 if $modbusdevice->write_single_coil($address,$newvalue);
        }
    }
    else
    {
        print STDERR "inputregister not known for address: $address\n";
    }
    print STDERR "Could not write to address: $address value:$newvalue\n";

    return undef;
}



sub readValuesFromModubus
{
    my($self,$address,$modbustype,$modbussize, $wordcount, $contenttype ) = (@_);

    print STDERR "readValuesFromModubus:$address modbustype:$modbustype modbussize:$modbussize wordcount:$wordcount contenttype:$contenttype\n" if $self->{debug};

    my $modbusdevice    = $self->{device};
    my $retrycounter    = 5;
    my $values          = undef;


    if(     $modbusdevice->is_open()
        &&  ( ($self->{connectionstarttime} + $self->{maximumconnecttime}) < time())  )
    {
        print STDERR "readValuesFromModubus:too long connected ".$self->isotime($self->{connectionstarttime})." - closing connection\n" if $self->{debug};
        $modbusdevice->close();
    }

    READ_VALUES: while(!$values && $retrycounter-->0)
    {
        print STDERR "readValuesFromModubus:retrycounter: $retrycounter\n" if $self->{debug};
        print STDERR "readValuesFromModubus:device is open:".$modbusdevice->is_open()." since: ".$self->isotime($self->{connectionstarttime})."\n" if $self->{debug};

        if( !$modbusdevice->is_open() )
        {
            if( $modbusdevice->open() )
            {
                print STDERR "readValuesFromModubus: Correctly opened modbus to:".$self->{host}."\n" if $self->{debug};
                $self->{connectionstarttime} = time();
            }
            else
            {
                print STDERR "readValuesFromModubus: ".localtime()." Could not open modbus to:".$self->{host}."\n";
                print STDERR "readValuesFromModubus: Sleeping 5 seconds before retry\n";
                sleep(5);
                next READ_VALUES;
            }
        }

        $values = $self->readvaluesFromModBusOnce($address,$modbustype,$modbussize, $wordcount, $contenttype );
        
        if( !$values )
        {
            print STDERR "readValuesFromModubus: ".localtime()." Could not read values from modbus device:".$self->{host}."\n";
            $modbusdevice->close() if !$modbusdevice->is_open();

            if( $retrycounter = 1 )
            {
                    print STDERR "readValuesFromModubus: could not read anything from Modbus device, calling reset\n";
                    $self->reset();
            }
            print STDERR "readValuesFromModubus: ".localtime()." Sleeping 5 seconds before retry\n"; sleep(5);
        }
    }
    print STDERR "readValuesFromModubus: read:".Data::Dumper->Dumper($values)."\n" if $self->{debug};
    
    return $values;
}



sub readvaluesFromModBusOnce
{
    my($self,$address,$modbustype,$modbussize, $wordcount, $contenttype ) = (@_);

    print STDERR "readvaluesFromModBusOnce:$address modbustype:$modbustype modbussize:$modbussize wordcount:$wordcount contenttype:$contenttype\n" if $self->{debug};
    
    my $modbusdevice = $self->{device};
    
    my $words;
    
    if( 'register' eq $modbustype )
    {
        print STDERR "readvaluesFromModBusOnce: read_input_registers($address,$wordcount)\n" if $self->{debug};

        $words = $modbusdevice->read_input_registers($address,$wordcount);
    }
    elsif( 'discrete' eq $modbustype )
    {
        print STDERR "readvaluesFromModBusOnce: read_discrete_inputs($address,$wordcount)\n" if $self->{debug};

        $words = $modbusdevice->read_discrete_inputs($address,$wordcount);
    }
    elsif( 'holding' eq $modbustype )
    {
        print STDERR "readvaluesFromModBusOnce: read_holding_registers($address,$wordcount)\n" if $self->{debug};

        $words = $modbusdevice->read_holding_registers($address,$wordcount);
    }
    elsif( 'coil' eq $modbustype )
    {
        print STDERR "readvaluesFromModBusOnce: read_coils($address,$wordcount)\n" if $self->{debug};

        $words = $modbusdevice->read_coils($address,$wordcount);
    }

    print STDERR "readvaluesFromModBusOnce: read:".Data::Dumper->Dumper($words)."\n" if $self->{debug};
    
    return undef if !defined( $words );
    
    my @values;
    
    while( @$words > 0 )
    {
        my $value;
        
        if( 'ascii' eq $contenttype )
        {
            while( @$words > 0 )
            {
                my $word = shift(@$words);

                my $valueA = (($word & 0xFF00)>>8);
                my $valueB = ($word & 0x00FF);
                $value .= sprintf "%s%s", ($valueA > 0x20 ? chr($valueA) : ''),($valueB > 0x20 ? chr($valueB) : '');
            }
        }
        elsif( $modbussize < 16 )
        {
            $value = shift(@$words);
        }
        elsif( 16 == $modbussize )
        {
            $value = shift(@$words);
        }
        elsif( 32 == $modbussize )
        {
            $value = (shift(@$words) << 16) | shift(@$words);
            $value = unpack('l',pack('L',$value)) if $contenttype eq 'SInt32';
        }
        elsif( 64 == $modbussize )
        {
            $value =  (shift(@$words) << 48) | (shift(@$words) << 32) | (shift(@$words) << 16) | (shift(@$words));
        }
        push @values, $value;
    }
    print STDERR "readvaluesFromModBusOnce: returning:".Data::Dumper->Dumper(\@values)."\n" if $self->{debug};
    return \@values;
}

1;

