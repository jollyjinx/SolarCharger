#
#	name:		Configuration.pm
#	purpose:	one modul for all config tasks
#
#	+ newFromDefaults(hash with entries: key => [defaultvalue,type] ,
#
#

package JNX::IniFiles;
use strict;
use Data::Dumper;
use JNX::JLog;

sub new
{
    my ($class,%options) = (@_);

    my $self = {};
    bless $self, $class;

    $self->{debug}      = $options{debug} || 0;
    $self->{filename}   = $options{filename} || 'config.ini';

    $self->{sectionhash} = $self->readContentsToHash();
    return $self;
}

sub readContentsToHash
{
    my($self) = @_;

    if( !open(FILE,$self->{filename}) )
    {
        JNX::JLog::error "error reading config file $!";
        return undef;
    }

    my $section = 'GLOBAL';

    my %sectionhash;

    LINE: while( my $line = <FILE> )
    {
        chomp $line;
        JNX::JLog::trace "Line: $line";

        next LINE if $line =~ m/^\s*(?:\;|\#|\/\/)/;  # ignore lines that start with ; or # or //

        if( $line =~ m/^\[(\S+)\]\s*/o )
        {
            $section = $1;
            JNX::JLog::trace "Section now: $section";
            next LINE;
        }
        if( $line =~ m/^([^=]+)\s*\=(.*)$/o )
        {
            my( $key, $value ) = ($1,$2);

            JNX::JLog::trace "key:$key = $value";

            $sectionhash{$section}{$key} = $value;
        }
    }

    close(FILE);

    return \%sectionhash;
}

#        if( my $configurationObject = JNX::IniFile->new( filename => $configurationfile ) )
#        {
#            ITERATE_KEYS: for my $key (keys %{$module_definitions})
#            {
#                my $value= $configurationObject->val($current_package_name,$key);   if(defined $value){ $$configurationfile_options{$key} = $value; next ITERATE_KEYS; }
#                my $value= $configurationObject->val($programname,$key);            if(defined $value){ $$configurationfile_options{$key} = $value; next ITERATE_KEYS; }
#                my $value= $configurationObject->val('GLOBAL',$key);                if(defined $value){ $$configurationfile_options{$key} = $value; next ITERATE_KEYS; }
#            }
#        }
#    }

sub val
{
    my($self,$section,$key) = @_;

    return $self->{sectionhash}{$section}{$key};
}

1;
