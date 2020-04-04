package JNX::HashHelper;
use strict;
use warnings;

use Data::Dumper;

use JNX::FileHelper;
use JNX::JLog;

sub checkHashForKeys
{
    my($hash,@required_keys) = (@_);

    my %required    = map { $_ => 1 } @required_keys;
    my @missing     = ();
    
    for my $key (@required_keys)
    {
        push(@missing,$key) if ! exists( $$hash{$key} );
    }
    
    JNX::JLog::error ": keys missing:".join(',',@missing)."from dictionary:".Data::Dumper->Dumper($hash) if @missing > 0;
    
    return @missing == 0;
}


sub mergeHashes
{
    my(@hashes) = @_;
    
    my %returnhash;
    
    for my $hash (@hashes)
    {
        next if !$hash;
    
        JNX::JLog::error "hash:".Data::Dumper->Dumper($hash) if 'HASH' ne ref($hash);
    
        while( my ($key,$value) = each %{$hash} )
        {
            $returnhash{$key} = $value;
        }
    }
    return \%returnhash;
}

sub valueForKeyPath
{
    my($keypath,$object) = @_;
    
    my @keypath = split(/\./,$keypath);
    
    return $object if 0 == @keypath;
    
    my $first_key = shift @keypath;
    
    my $new_keypath = join('.',@keypath);
    my $reftype = ref($object);
#    JNX::JLog::error 'first_key:'.$first_key.'$reftype:'.$reftype.'$new_keypath:'.$new_keypath;

    if('HASH' eq $reftype)
    {
        return valueForKeyPath( $new_keypath, $$object{$first_key});
    }
    elsif('ARRAY' eq $reftype)
    {
        return valueForKeyPath( $new_keypath, $$object[$first_key]);
    }
    elsif('SCALAR')
    {
        return $object;
    }
    die "weird".Data::Dumper->Dumper("object:$object");
}


sub allKeyPaths
{
    my($object,$currentkeypath) = @_;

    my  $reftype        = ref($object);
        $currentkeypath .= '';
    
#    JNX::JLog::error ''.Data::Dumper->Dumper([$object,$currentkeypath,$reftype]);
    
    return [] if '' eq $reftype;
    return [] if 'SCALAR' eq $reftype;

    if('HASH' eq $reftype)
    {
        my @keypaths;# = ($currentkeypath);
    
        for my $key (sort keys %{$object})
        {
            my @subkeypaths = sort @{allKeyPaths($$object{$key},$key)};
            
#            JNX::JLog::error ''.Data::Dumper->Dumper(@subkeypaths);
        
            if( 0 == @subkeypaths )
            {
                push(@keypaths,$key);
            }
            else
            {
                for my $subkeypath (@subkeypaths)
                {
#                    JNX::JLog::error 'current:'.$subkeypath.'  key:'.$key.'  keypath:'.$subkeypath;
                    push(@keypaths,$key.'.'.$subkeypath);
                }
            }
        }
        return \@keypaths;
    }
    elsif('ARRAY' eq $reftype)
    {
        my @keypaths;
    
        for my $key (0..$#$object)
        {
            my @subkeypaths = sort @{allKeyPaths($$object[$key],$key)};
        
#            JNX::JLog::error ''.Data::Dumper->Dumper(@subkeypaths);
        
            if( 0 == @subkeypaths )
            {
                push(@keypaths,$key);
            }
            else
            {
                for my $subkeypath (@subkeypaths)
                {
#                    JNX::JLog::error 'current:'.$subkeypath.'  key:'.$key.'  keypath:'.$subkeypath;
                    push(@keypaths,$key.'.'.$subkeypath);
                }
            }
        }
        return \@keypaths;
    }
    return [];
}

sub equals
{
    my($a,$b) = @_;
    
#    JNX::JLog::error ''.Data::Dumper->Dumper([$a,$b]);
    
    my $CMP_DIFFER  = 0;
    my $CMP_SAME    = 1;
    
    my $defined_a = defined $a;
    my $defined_b = defined $b;
    
    return $CMP_SAME    if !$defined_a && !$defined_b;
    return $CMP_DIFFER  if  $defined_a !=  $defined_b;

    my $ref_a = ref($a);
    my $ref_b = ref($b);
    
    return $CMP_DIFFER if $ref_a ne $ref_b;
    
    
    if( 'HASH' eq $ref_a )
    {
        my $keys_a = [sort keys %{$a}];
        my $keys_b = [sort keys %{$b}];
    
        return $CMP_DIFFER if !equals($keys_a,$keys_b);
    
        while( my($key,$value_a) = each %{$a} )
        {
            my $value_b = $${b}{$key};
        
            return $CMP_DIFFER if !equals($value_a,$value_b);
        }
        return $CMP_SAME;
    }
    elsif( 'ARRAY' eq $ref_a )
    {
        my $last_a = $#$a;
        my $last_b = $#$b;

        return $CMP_DIFFER if $last_a != $last_b;
   
        for my $index (0..$last_a)
        {
            my $value_a = $$a[$index];
            my $value_b = $$b[$index];

            return $CMP_DIFFER if !equals($value_a,$value_b);
        }
        return $CMP_SAME;
    }
    elsif( 'SCALAR' eq $ref_a )
    {
        return ($$a eq $$b);
    }
    return ($a eq $b);
}


sub diffHashes
{
    my($a,$b ) = @_;
    
    my $keypaths_a = allKeyPaths($a);
    my $keypaths_b = allKeyPaths($b);
#    JNX::JLog::debug "AAA".Data::Dumper->Dumper( $keypaths_a);
#    JNX::JLog::debug "BBB".Data::Dumper->Dumper( $keypaths_b);

    my %all_keypaths;
    
    for (@{$keypaths_a}) { $all_keypaths{$_} = undef; }
    for (@{$keypaths_b}) { $all_keypaths{$_} = undef; }

    #JNX::JLog::debug "".Data::Dumper->Dumper( \%all_keypaths);

    my @differences;
    for my $path (sort keys %all_keypaths)
    {
        my $value_a = valueForKeyPath($path,$a);
        my $value_b = valueForKeyPath($path,$b);
        push(@differences,$path) if !(defined $value_a && defined $value_b && $value_a eq $value_b);
    }
#    JNX::JLog::debug "RESULT".Data::Dumper->Dumper( \@differences);
    return \@differences;
}









self_test() if not caller();

1;


sub self_test
{
    require Test::More;
    import Test::More;

    test_equals();
    test_allkeypaths();
    test_keypath();
    test_diffHashes();
    
    done_testing() ;
}

sub test_diffHashes
{
    JNX::JLog::debug "testing test_allkeypaths()";

    ok( equals(diffHashes( { 'a' => 'b' }                           ,{ 'a' => { 'b' => { 'c' => 'd' }  } }               ), ['a', 'a.b.c'] ));
    ok( equals(diffHashes( { 'a' => { 'b' => { 'c' => 'd' }  } }    ,{ 'a' => { 'b' => { 'c' => 'd' }  } }               ), [] ));
    ok( equals(diffHashes( { 'a' => { 'b' => { 'c' => 'd' }  } }    ,{ 'a' => { 'b' => { 'd' => 'c' }  } }               ), ['a.b.c','a.b.d'] ));
    ok( equals(diffHashes( { 'a' => { 'b' => { 'c' => [0,1,2] } } } ,{ 'a' => { 'b' => { 'c' => [0,1,2] } } }            ), [] ));
    ok( equals(diffHashes( { 'a' => { 'b' => { 'c' => [0,1,2] } } } ,{ 'a' => { 'b' => { 'c' => [2,1,2] } } }            ), ['a.b.c.0'] ));
    ok( equals(diffHashes( { 'a' => { 'b' => { 'c' => [5,{ 'd' => { 'e' => { 'f' => 'g' }  } },7] }  } }  ,{ 'a' => { 'b' => { 'c' => [5,{ 'd' => { 'e' => { 'f' => 'h' }  } },7] }  } }    ), ['a.b.c.1.d.e.f'] ));
    
    ok( equals(diffHashes(  { 'a' => { 'b' => { 'c' => [5,{ 'd' => { 'e' => { 'f' => 'g' }  } },7] }  } }  ,
                            { 'a' => { 'b' => { 'd' => [5,{ 'd' => { 'e' => { 'f' => 'h' }  } },7] }  } }
                        ),
                            [
                              'a.b.c.0',
                              'a.b.c.1.d.e.f',
                              'a.b.c.2',
                              'a.b.d.0',
                              'a.b.d.1.d.e.f',
                              'a.b.d.2'
                            ]
     ));
}

sub test_allkeypaths
{
    JNX::JLog::debug "testing test_allkeypaths()";

    ok( equals(allKeyPaths( { 'a' => 'b' }                                                                                ), ['a'] ));
    ok( equals(allKeyPaths( { 'a' => { 'b' => { 'c' => 'd' }  } }                                                         ), [ 'a.b.c'] ));
    ok( equals(allKeyPaths( { 'a' => { 'b' => { 'c' => [5,{ 'd' => { 'e' => { 'f' => 'g' }  } },7] }  } }                 ), [ 'a.b.c.0','a.b.c.1.d.e.f','a.b.c.2'] ));
}

sub test_keypath
{
    JNX::JLog::debug "testing keypath()";
    
    is( valueForKeyPath( 'a'         , { 'a' => 'b' }                                        ), 'b' );
    is( valueForKeyPath( 'b'         , { 'a' => 'b' }                                        ), undef );

    ok( equals(valueForKeyPath( 'a'         , { 'a' => {} } ), {}) );

    is( valueForKeyPath( 'a.b.c'     , { 'a' => { 'b' => { 'c' => 'd' }  } }                 ), 'd' );
    is( valueForKeyPath( 'a.b.c.1.d.e.f'     , { 'a' => { 'b' => { 'c' => [5,{ 'd' => { 'e' => { 'f' => 'g' }  } },7] }  } }             ), 'g' );
}

sub test_equals
{
    JNX::JLog::debug "testing equals()";
    
    ok( equals( undef  , undef        ));
    ok( equals( {}  , {}        ));
    ok( !equals( 1  , undef        ));
    ok( !equals( undef  , 1        ));
    ok(  equals( 1  , 1        ));
    ok( !equals( 1 , 0        ));
    ok(  equals( 0  , 0        ));
    ok(  equals( -1 , -1       ));
    ok(  equals( '{}' , '{}'   ));
    ok(  equals( 'a', 'a'      ));
    ok( !equals( 'a', 'b'      ));

    ok( !equals( \{}, 'b'      ));
    
    ok(  equals( ['a'] , ['a']   ));
    ok( !equals( []    , ['a']   ));
    ok( !equals( ['b'] , ['a']   ));
    ok(  equals( ['a','b'] , ['a','b']   ));
    ok( !equals( ['b','a'] , ['a','b']   ));
    ok( !equals( ['b','a','c'] , ['a','b']   ));
    ok( !equals( ['b','a','c'] , []   ));
    ok(  equals( ['b',{ 'a' => ['b','a','c'] , 'b'=>'a' },'c'] , ['b',{ 'a' => ['b','a','c'] , 'b'=>'a' },'c']   ));
    ok( !equals( ['b',{ 'a' => ['b','a','c'] , 'b'=>'a' },'c'] , ['b',{ 'a' => ['b','a','d'] , 'b'=>'a' },'c']   ));

    ok( !equals( {} , []   ));
    ok( !equals( { 'a' => 'b' } , []   ));
    ok(  equals( { 'a' => 'b' } , { 'a' => 'b' }   ));
    ok( !equals( { 'a' => 'b' , 'b'=>'a' } , { 'a' => 'b' }   ));
    ok(  equals( { 'a' => 'b' , 'b'=>'a' } , { 'b'=>'a','a' => 'b' }   ));
    ok( !equals( { 'a' => 'b' , 'b'=>'a' } , { 'b'=>'a','a' => 'c' }   ));
    ok(  equals( { 'a' => [] , 'b'=>'a' } , { 'b'=>'a','a' => [] }   ));
    ok(  equals( { 'a' => ['b','a','c'] , 'b'=>'a' } , { 'b'=>'a','a' => ['b','a','c'] }   ));
    ok(  equals( { 'a' => { 'a' => 'b' , 'b'=>'a' } , 'b'=>'a' } , { 'b'=>'a','a' => { 'a' => 'b' , 'b'=>'a' } }   ));
    ok(  !equals( { 'a' => { 'a' => 'b' , 'b'=>'a' } , 'b'=>'a' } , { 'b'=>'a','a' => { 'a' => 'b' , 'b'=>'c' } }   ));
}


