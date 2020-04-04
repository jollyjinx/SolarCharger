package JNX::FileHelper;
use 5.010;      # this is for correct utf8 handling
use utf8;
use strict;

use JNX::JLog;


sub contentsOfFileWithEncoding
{
    my($filename,$encoding) = (@_);
    
    if( !open(FILE,$filename) )
    {
        JNX::JLog::error "Could not open file:$filename due to:$!";
        return undef;
    }
 
    local $/ = undef;
    binmode FILE,$encoding;
    
    my $filecontents = <FILE>;
    close(FILE);
    
    return $filecontents;
}


sub writeToFileWithEncoding
{
    my($filename,$filecontents,$encoding) = (@_);

    if( !open(FILE,'>'.$filename) )
    {
        JNX::JLog::error "Could not write to file:$filename due to:$!";
        return undef;
    }
    binmode FILE, $encoding;

    print FILE $filecontents;
    close(FILE);
    
    return 1;
}

sub contentsOfFile
{
    return contentsOfFileWithEncoding(@_,':raw');
}

sub writeToFile
{
    my($filename,$filecontent) = (@_);
    return writeToFileWithEncoding($filename,$filecontent,':raw');
}
#
#
#sub contentsOfUTF8File
#{
#    my $filecontent = contentsOfFileWithEncoding(@_,':encoding(UTF-8)');
#
#    $filecontent =~ s/\N{U+FEFF}//;
#    $filecontent =~ s/\x{FEFF}//;
#    $filecontent =~ s/\N{U+FEFF}//;
#    $filecontent =~ s/\N{ZERO WIDTH NO-BREAK SPACE}//;
#    $filecontent =~ s/\N{BOM}//;   # Convenient alias
#
#    return $filecontent;
#}
#sub writeToUTF8File
#{
#    my($filename,$filecontent) = (@_);
#
#    $filecontent =~ s/\N{U+FEFF}//;
#    $filecontent =~ s/\x{FEFF}//;
#    $filecontent =~ s/\N{U+FEFF}//;
#    $filecontent =~ s/\N{ZERO WIDTH NO-BREAK SPACE}//;
#    $filecontent =~ s/\N{BOM}//;   # Convenient alias
#
#    return writeToFileWithEncoding($filename,$filecontent,':encoding(UTF-8)');
#}
#

1;
