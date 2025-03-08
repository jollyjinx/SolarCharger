#!/usr/bin/perl
use Config;
use strict;
use Time::HiRes qw(usleep);
use POSIX;
use Data::Dumper;
use MBclient;
use Carp;
use JSON::PP;
use JNX::JLog;

package JNX::ModbusDevice;

my $PSEUDO64BITMAX = convert64bit( pack("c*",0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF,0xFF) );

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

    $options{host}          ||  Carp::croak "Missing host";
    $options{devicename}    ||  Carp::croak "Missing devicename";

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
    JNX::JLog::error "";
}

sub DESTROY
{
    my($self) = @_;

    JNX::JLog::error "";

    $self->{device}->close();
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

        my $value = $self->readAddress($address);
        
        printf "%40s %3d:",$inputregisters{$address}{description},$address;

        if( 'hex' eq $inputregisters{$address}{valuetype} )
        {
            printf "0x%04x ",$value;
        }
        elsif( 'bit' eq $inputregisters{$address}{valuetype} )
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
        print "\t".$inputregisters{$address}{description};
    }
    print "\n";
}

sub showLoopLine
{
    my($self) = @_;
    
    print $self->isotime();
    
    for my $address ( $self->loopAddresses() )
    {
        my $value = $self->readAddress($address);
    
        print "\t".$value;
    }
    print "\n";
}


sub loopLineData
{
    my($self) = @_;


    my %inputregisters = %{$self->{inputregisters}};

    my $isotime     = $self->isotime();

    my @values;
    for my $address ( $self->loopAddresses() )
    {
        my $value = $self->readAddress($address);                   JNX::JLog::trace "address:$address name:$inputregisters{$address}{name} value:$value";

        if( 'NaN' eq $value && $inputregisters{$address}{valuetype} ne 'ascii' )
        {
            $value = undef;
        }

        push( @values ,      {  value   =>  $value,
                                address => $address,
                                title   => $inputregisters{$address}{description},
                                topic   => $inputregisters{$address}{name},
                                unit    => $inputregisters{$address}{unit},
                                payload => $value,

                                devicename => $self->{devicename},
                                'time'  => $isotime,
                            });
    }

    JNX::JLog::trace "values: ".Data::Dumper->Dumper(\@values);
    return \@values; #%value;
}


sub showLoopLineJSON
{
    my($self) = @_;

    my $value = $self->loopLineData();

    print JSON::PP::encode_json($value);
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

    JNX::JLog::debug "readAddress:$address";
    
    my $returnvalue = undef;
    
    if( my $register = $self->{inputregisters}{$address} )
    {
        JNX::JLog::debug "readAddress:inputregister :".Data::Dumper->Dumper($register);

        $returnvalue = $self->readValuesFromModubus($address,$$register{modbustype},$$register{modbussize},$$register{wordcount},$$register{valuetype},$$register{factor});
    }
    else
    {
        JNX::JLog::error "inputregister not known for address: $address\n";
    }
    
    $self->{cache}{$address}{time}  = time();
    $self->{cache}{$address}{value} = $returnvalue;
    
    return $returnvalue;
}


sub readAddressFromCache
{
    my($self,$address) = @_;

    JNX::JLog::debug "readAddressFromCache:$address";
    
    return $self->{cache}{$address}{value} || $self->readAddress($address);
}



sub writeAddress
{
    my($self,$address,$newvalue) = @_;
    
    JNX::JLog::debug "writeAddress:$address newvalue:$newvalue";


    my $returnvalue = undef;

    if( my $register = $self->{inputregisters}{$address} )
    {
        JNX::JLog::debug "writeAddress:inputregister :".Data::Dumper->Dumper($register)."\n";
        
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
        JNX::JLog::error "inputregister not known for address: $address";
    }
    JNX::JLog::error "Could not write to address: $address value:$newvalue";

    return undef;
}



sub readValuesFromModubus
{
    my($self,$address,$modbustype,$modbussize, $wordcount, $valuetype ,$factor ) = (@_);

    JNX::JLog::debug  "$address modbustype:$modbustype modbussize:$modbussize wordcount:$wordcount valuetype:$valuetype";

    my $modbusdevice    = $self->{device};
    my $retrycounter    = 5;
    my $value          = undef;


    if(     $modbusdevice->is_open()
        &&  ( ($self->{connectionstarttime} + $self->{maximumconnecttime}) < time())  )
    {
        JNX::JLog::debug "too long connected ".$self->isotime($self->{connectionstarttime})." - closing connection";
        $modbusdevice->close();
    }

    READ_VALUES: while($value == undef && $retrycounter-->0)
    {
        JNX::JLog::debug "retrycounter: $retrycounter";
        JNX::JLog::debug "device is open:".$modbusdevice->is_open()." since: ".$self->isotime($self->{connectionstarttime});

        if( !$modbusdevice->is_open() )
        {
            if( $modbusdevice->open() )
            {
                JNX::JLog::debug "Correctly opened modbus to:".$self->{host};
                $self->{connectionstarttime} = time();
            }
            else
            {
                JNX::JLog::error "Could not open modbus to:".$self->{host};
                JNX::JLog::error "readValuesFromModubus: Sleeping 5 seconds before retry";
                sleep(5);
                next READ_VALUES;
            }
        }

        $value = $self->readvaluesFromModBusOnce($address,$modbustype,$modbussize, $wordcount, $valuetype ,$factor);
        
        if( !defined( $value ) )
        {
            JNX::JLog::error "Could not read values from modbus device:".$self->{host};
            $modbusdevice->close() if !$modbusdevice->is_open();

            if( $retrycounter = 1 )
            {
                    JNX::JLog::error "readValuesFromModubus: could not read anything from Modbus device, calling reset";
                    $self->reset();
            }
            JNX::JLog::error "Sleeping 5 seconds before retry";
            sleep(5);
        }
    }
    JNX::JLog::debug "readValuesFromModubus: read:".Data::Dumper->Dumper($value);

    return $value;
}



sub readvaluesFromModBusOnce
{
    my($self,$address,$modbustype,$modbussize, $wordcount, $valuetype ,$factor) = (@_);

    JNX::JLog::debug "readvaluesFromModBusOnce:$address modbustype:$modbustype modbussize:$modbussize wordcount:$wordcount valuetype:$valuetype factor:$factor";

    if   ( 'char' eq $valuetype   )  { }
    elsif( 'ascii' eq $valuetype  )  { }
    elsif( 'UInt8'  eq $valuetype )  { $wordcount = 1; $modbussize = 2; }
    elsif( 'SInt8'  eq $valuetype )  { $wordcount = 1; $modbussize = 2; }
    elsif( 'UInt16' eq $valuetype )  { $wordcount = 1; $modbussize = 2; }
    elsif( 'SInt16' eq $valuetype )  { $wordcount = 1; $modbussize = 2; }
    elsif( 'UInt32' eq $valuetype )  { $wordcount = 2; $modbussize = 4; }
    elsif( 'SInt32' eq $valuetype )  { $wordcount = 2; $modbussize = 4; }
    elsif( 'UInt64' eq $valuetype )  { $wordcount = 4; $modbussize = 8; }
    elsif( 'SInt64' eq $valuetype )  { $wordcount = 4; $modbussize = 8; }
    else
    {
        JNX::JLog::error  "Unknown content: $valuetype";
    }
    JNX::JLog::trace "readvaluesFromModBusOnce2:$address modbustype:$modbustype modbussize:$modbussize wordcount:$wordcount valuetype:$valuetype factor:$factor";



    my $modbusdevice = $self->{device};
    my $words;
    
    if( 'register' eq $modbustype )
    {
        JNX::JLog::trace "read_input_registers($address,$wordcount)";

        $words = $modbusdevice->read_input_registers($address,$wordcount);
    }
    elsif( 'discrete' eq $modbustype )
    {
        JNX::JLog::trace "read_discrete_inputs($address,$wordcount)";

        $words = $modbusdevice->read_discrete_inputs($address,$wordcount);
    }
    elsif( 'holding' eq $modbustype )
    {
        JNX::JLog::trace "read_holding_registers($address,$wordcount)";

        $words = $modbusdevice->read_holding_registers($address,$wordcount);
    }
    elsif( 'coil' eq $modbustype )
    {
        JNX::JLog::trace "read_coils($address,$wordcount)";

        $words = $modbusdevice->read_coils($address,$wordcount);
    }
    JNX::JLog::trace "read:".Data::Dumper->Dumper($words);

    return undef if !defined( $words );

    my $networkvalue = pack('n*',@$words);
    JNX::JLog::trace "Packed content:".Data::Dumper->Dumper($networkvalue);

    return undef if !defined( $networkvalue );

    my $value = undef;
        
    if(    'char'   eq $valuetype )  { $value = pack('c',unpack('n',$networkvalue)); }
    elsif( 'ascii'  eq $valuetype )  { $value = unpack('Z*',$networkvalue); }
    elsif( 'UInt8'  eq $valuetype )  { $value = unpack('c',$networkvalue);                          JNX::JLog::trace "Raw content ($valuetype):".$value;    if($value ==  2**8-1)    { $value = undef } }
    elsif( 'SInt8'  eq $valuetype )  { $value = unpack('C',$networkvalue);                          JNX::JLog::trace "Raw content ($valuetype):".$value;    if($value ==  -2**7)     { $value = undef } }
    elsif( 'UInt16' eq $valuetype )  { $value = unpack('n',$networkvalue);                          JNX::JLog::trace "Raw content ($valuetype):".$value;    if($value ==  2**16-1)   { $value = undef } }
    elsif( 'SInt16' eq $valuetype )  { $value = unpack('s',pack('S',unpack('n',$networkvalue)));    JNX::JLog::trace "Raw content ($valuetype):".$value;    if($value ==  -2**15)    { $value = undef } }
    elsif( 'UInt32' eq $valuetype )  { $value = unpack('N',$networkvalue);                          JNX::JLog::trace "Raw content ($valuetype):".$value;    if($value ==  2**32-1)   { $value = undef } }
    elsif( 'SInt32' eq $valuetype )  { $value = unpack('l',pack('L',unpack('N',$networkvalue)));    JNX::JLog::trace "Raw content ($valuetype):".$value;    if($value ==  -2**31)    { $value = undef } }
    elsif(  'UInt64' eq $valuetype
         || 'SInt64' eq $valuetype ) { $value = int(convert64bit($networkvalue));                   JNX::JLog::trace "Raw content ($valuetype):".$value;    if($value == $PSEUDO64BITMAX ) { $value = undef } }
    else
    {
        JNX::JLog::error  "Unknown content: $valuetype";
    }

    JNX::JLog::trace "Decoded content ($valuetype):".$value;

    if( defined($value) )
    {
        $value = $value * $factor if defined($factor);
    }
    else
    {
        $value = 'NaN';
    }
    JNX::JLog::trace "Resulting value ($valuetype):".$value;


    return $value;
}


sub convert64bit        # warning - not a real 64bit conversion
{
    my($networkvalue) = @_;

    my($a,$b) = unpack('N2',$networkvalue);

    my $value = ($Config::Config{use64bitint}) ? ($a << 32 | $b ) : $b;

    JNX::JLog::trace "64bit value: $value\n";

    return $value;
}

1;

