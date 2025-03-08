package JNX::Date;
use strict;
use warnings;
use utf8;
use HTTP::Date;

use POSIX;

sub iso8601
{
    my($time) = @_;
    
    my $now = defined $time ? $time : time();
    
    return POSIX::strftime("%Y-%m-%dT%H:%M:%S%z",localtime($now))
}

sub toISO8601
{
    my($time) = @_;

    return POSIX::strftime("%Y-%m-%dT%H:%M:%SZ",gmtime($time));
}

sub fromISO8601
{
    my($timestring) = @_;
    return str2time($timestring);
}

sub watchhandForLocalTime
{
    my($time) = @_;
    
    my @watch_hands = ('🕛','🕧','🕐','🕜','🕑','🕝','🕒','🕞','🕓','🕟','🕔','🕠','🕕','🕡','🕖','🕢','🕗','🕣','🕘','🕤','🕙','🕥','🕚','🕦');

    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($time);
    
    my $seconds_on_day      = ( ($hour %12) * 3600 ) + ($min * 60 ) + ($sec) ;
    my $rounded_half_hours  = int( ($seconds_on_day + (15 * 60 )) / (30 * 60) ) % 24;

    
    if( $rounded_half_hours >= 0 && ($rounded_half_hours < scalar(@watch_hands)) )
    {
        return $watch_hands[$rounded_half_hours];
    }
    return '⏰';
}


self_test() if not caller();

1;


sub self_test
{
    require Test::More;
    import Test::More;

    plan(tests => (3 + 3 + 4 + 5 + (25*60*60)) );
    
    my  $start_time =  946684800;  # 1.1.2000 0:0:0 GMT
        $start_time -= 3600;        #   watchhand is localtime not gmt

    is( iso8601($start_time                 ),'2000-01-01T00:00:00+0100');
    is( iso8601($start_time + 1             ),'2000-01-01T00:00:01+0100');
    is( iso8601($start_time - 1             ),'1999-12-31T23:59:59+0100');

    
    is(watchhandForLocalTime($start_time -1                  ),'🕛');
    is(watchhandForLocalTime($start_time                     ),'🕛');
    is(watchhandForLocalTime($start_time + (15*60)-1         ),'🕛');
    
    is(watchhandForLocalTime($start_time + (15*60)           ),'🕧');
    is(watchhandForLocalTime($start_time + (30*60)-1         ),'🕧');
    is(watchhandForLocalTime($start_time + (30*60)           ),'🕧');
    is(watchhandForLocalTime($start_time + (45*60)-1         ),'🕧');
    
    is(watchhandForLocalTime($start_time + (45*60)           ),'🕐');
    is(watchhandForLocalTime($start_time + (45*60)+1         ),'🕐');
    is(watchhandForLocalTime($start_time + (59*60)-1         ),'🕐');
    is(watchhandForLocalTime($start_time + (60*60)           ),'🕐');
    is(watchhandForLocalTime($start_time + (60*60)+1         ),'🕐');

    for( my $hour=0; $hour < 25; $hour++)
    {
    for( my $minute=0; $minute < 60; $minute++)
    {
    for( my $seconds=0; $seconds < 60; $seconds++)
    {
        my $offset = ($hour*3600) + ($minute*60) + $seconds;
        my $t = $start_time + $offset;
        my $result = watchhandForLocalTime($t);
    
    
        isnt( $result,'⏰' , sprintf "offset:%5d (%02d:%02d:%02d) resulted in %s",$offset,$hour,$minute,$seconds,$result );
    }
    }
    }
    

}
