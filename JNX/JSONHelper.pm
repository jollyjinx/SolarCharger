package JNX::JSONHelper;
use strict;

use JSON -support_by_pp;
use JNX::FileHelper;
use JNX::HashHelper;

sub hashFromJSONString
{
    my($jsonstring) = @_;

    return undef if !length($jsonstring);

    my $jsonhash;

#    eval { $jsonhash = JSON::from_json($jsonstring,{ utf8  => 1 }); };
#    eval { $jsonhash = JSON::PP->new->utf8(1)->decode( $message ) };
    eval {  my $json = JSON::PP->new;
                $json->utf8(1);
                my ($true,$false) = ( JSON::true,JSON::false );
                $json->boolean_values(JSON::false,JSON::true);
            $jsonhash = $json->decode($jsonstring)  };

    return $jsonhash if 'HASH' eq ref($jsonhash);
    return $jsonhash if 'ARRAY' eq ref($jsonhash);

    return undef;
}

sub hashFromJSONStringRequiredKeys
{
    my($jsonstring,@requiredkeys) = (@_);

    return undef if !length($jsonstring);

    my $jsonhash = hashFromJSONString($jsonstring);

    if(@requiredkeys > 0)
    {
        return undef if !JNX::HashHelper::checkHashForKeys($jsonhash,@requiredkeys);
    }

    return $jsonhash;
}


sub readFromFileRequiredKeys
{
    my($filename,@requiredkeys) = (@_);

    if( my $jsonstring = JNX::FileHelper::contentsOfFile($filename) )
    {
        return hashFromJSONStringRequiredKeys($jsonstring,@requiredkeys);
    }
    return undef;
}

sub hashToJSON
{
    my($jsonhash) = @_;

    my  $jsonstring = JSON::to_json( $jsonhash  ,{ utf8  => 1 , pretty => 1 , canonical => 1} );
        $jsonstring =~ s/("\s*:\s*)NaN([\s,}]+)/${1}null${2}/g;

    return $jsonstring;
}

sub writeToFile
{
    my($filename,$jsonobject) = (@_);

    my $jsonstring = JSON::to_json( $jsonobject  ,{ utf8  => 1 , pretty => 1 , canonical => 1} );

    return JNX::FileHelper::writeToFile($filename,$jsonstring);
}


1;
