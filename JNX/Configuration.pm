#
#	name:		Configuration.pm
#	purpose:	one modul for all config tasks
#
#	+ newFromDefaults(hash with entries: key => [defaultvalue,type] ,
#
#

package JNX::Configuration;
use strict;
use Data::Dumper;
use Getopt::Long;
use JNX::IniFiles;
use JNX::HashHelper;
use JNX::JLog;

my $alloptions;

sub newFromDefaults
{
	my(%module_defaults) = @_;
	
    my  $current_package_name        = (caller(0))[0] || (caller(1))[0];
    my  $current_package_is_module   = $current_package_name ne 'main';
    my  $current_package_prefix      = $current_package_name.'-';
        $current_package_prefix      =~ s/:+/-/g;
    my  $programname    = $0;
        $programname    =~ s/^.*\///;
    my  $current_module_name        = ($current_package_is_module ? $current_package_name : $programname);


    my  $always_supported_options = {  'loglevel'         =>  ['warn','string'],
                                       'configfilename'   =>  ['config.ini','string'],
                                    };
    my  $main_supported_options   = {
                                      'help'                    =>  ['','flag'],
                                    } if !$current_package_is_module;


    my $module_definitions          = JNX::HashHelper::mergeHashes($always_supported_options,$main_supported_options,\%module_defaults);
    my $all_module_default_options  = {map { $_ => $$module_definitions{$_}[0] } keys %{$module_definitions}};
    
    JNX::JLog::trace 'current module name:'.$current_module_name;
    JNX::JLog::trace 'current package name:'.$current_package_name;
    JNX::JLog::trace $current_package_name.'$module_definitions:'.Data::Dumper->Dumper($module_definitions);
    JNX::JLog::trace $current_package_name.'$all_module_default_options:'.Data::Dumper->Dumper($all_module_default_options);

    my $all_options_merged;
    my $commandline_options_merged;
    {
        my %option_converter = ('string' => '=s', 'number' =>,'=i', 'flag'=>'','option'=>'', 'intarray' => '=s' );

        my @module_options;
        my @global_options;
    
        while( my($option,$valuearray) = each %{$module_definitions} )
        {
            my($defaultvalue,$type,$required) = @{$valuearray};
        
            $$all_options_merged{$option} = $defaultvalue;
        
            push(@global_options,                         $option.$option_converter{$type});
            push(@module_options, $current_package_prefix.$option.$option_converter{$type});
        }
    
        #JNX::JLog::error $current_package_name.'options:'.Data::Dumper->Dumper($all_options_merged);

        my $commandline_options_global = readGetOptionsFromCommandline($current_package_prefix,@global_options);
        my $commandline_options_module = readGetOptionsFromCommandline($current_package_prefix,@module_options);

        #JNX::JLog::error $current_package_name.'$commandline_options_global:'.Data::Dumper->Dumper($commandline_options_global);
        #JNX::JLog::error $current_package_name.'$commandline_options_module:'.Data::Dumper->Dumper($commandline_options_module);
    
        $commandline_options_merged = JNX::HashHelper::mergeHashes($commandline_options_global,$commandline_options_module);
        #JNX::JLog::error $current_package_name.'$commandline_options_merged:'.Data::Dumper->Dumper($commandline_options_merged);
    }

    my $configurationfile = $$commandline_options_merged{'configfilename'} || $$all_options_merged{'configfilename'};
    #JNX::JLog::error $current_package_name.'$configurationfile:'.Data::Dumper->Dumper($configurationfile);

    my $configurationfile_options;
    
    if( -e $configurationfile )
    {
        if( my $configurationObject = JNX::IniFiles->new( filename => $configurationfile ) )
        {
            ITERATE_KEYS: for my $key (keys %{$module_definitions})
            {
                my $value= $configurationObject->val($current_package_name,$key);   if(defined $value){ $$configurationfile_options{$key} = $value; next ITERATE_KEYS; }
                my $value= $configurationObject->val($programname,$key);            if(defined $value){ $$configurationfile_options{$key} = $value; next ITERATE_KEYS; }
                my $value= $configurationObject->val('GLOBAL',$key);                if(defined $value){ $$configurationfile_options{$key} = $value; next ITERATE_KEYS; }
            }
        }
    }
#    JNX::JLog::error $current_package_name.'$configurationfile_options:'.Data::Dumper->Dumper($configurationfile_options);

    
    $all_options_merged = JNX::HashHelper::mergeHashes(($current_package_is_module?$main_supported_options:undef),$all_module_default_options,$configurationfile_options,$commandline_options_merged);
    
    #JNX::JLog::error $current_package_name.'$configurationfile_options:'.Data::Dumper->Dumper($configurationfile_options);

    
    $$alloptions{$current_package_name}{definition}     = $module_definitions;
    $$alloptions{$current_package_name}{merged}         = $all_options_merged;
    $$alloptions{$current_package_name}{name}           = $current_module_name;
 #   $$alloptions{$current_package_name}{default}        = $all_module_default_options;
 #   $$alloptions{$current_package_name}{commandline}    = $commandline_options_merged;
 #   $$alloptions{$current_package_name}{configfile}     = $configurationfile_options;

    if( !$current_package_is_module )
    {
        my @packages = ('main',sort grep(!/^main$/ , keys %{$alloptions}) );

        my $showhelp = $$all_options_merged{'help'};
        my $helptext = '';
        my $longest_option  = 10;
        my $longest_value   = 10;

        for my $package (@packages)
        {
            my $definition  = $$alloptions{$package}{definition};
            my $merged      = $$alloptions{$package}{merged};

            for my $option_name (sort keys %{$definition})
            {
                my $value = $$merged{$option_name};
                my($defaultvalue,$type,$required) = @{$$definition{$option_name}};
            
                $longest_option = maximum($longest_option,length ''.$option_name);
                $longest_value  = maximum($longest_value,length ''.$value);
#                 JNX::JLog::error sprintf  "%s option: %s (%2d max:%2d) value: %s (%2d max:%2d)",$package,$option_name,length($option_name),$longest_option,$value,length($value),$longest_value;
            }
        }
        $longest_option = minimum(18,$longest_option)   + 2;
        $longest_value  = minimum(10,$longest_value)    + 2;
#        JNX::JLog::error sprintf  "(max:%2d max:%2d)",$longest_option,$longest_value;
    
        for my $package (@packages)
        {
            my $definition  = $$alloptions{$package}{definition};
            my $merged      = $$alloptions{$package}{merged};
            my $name        = $$alloptions{$package}{name};

            my $modulehelp;

            for my $option_name (sort keys %{$definition})
            {
                my $value = $$merged{$option_name};
                my($defaultvalue,$type,$required) = @{$$definition{$option_name}};
                my $valueerror = 0;

                if( $required && !defined $value)
                {
                    $valueerror = 1;
                    $showhelp   = 1;
                }
                $modulehelp .= sprintf("  --%-$longest_option\s: %-$longest_value\s [%s%s%s]\n",$option_name,($valueerror?'*MISSING*':$value),$type,($required?', required':''),(defined $defaultvalue ?', default:'.$defaultvalue:''));
                # JNX::JLog::error $current_package_name.'$@packages:'.Data::Dumper->Dumper(\@packages);
            }

            if( $modulehelp )
            {
                $helptext .= '['.$name."]\n".$modulehelp;
            }
        }
    
        die $helptext if $showhelp;
        JNX::JLog::error $current_package_name.'log level:'. $$all_options_merged{'loglevel'};
        JNX::JLog::setLevel( $$all_options_merged{'loglevel'} );
    }
#         exit;
       #JNX::JLog::error $current_package_name.'$alloptions:'.Data::Dumper->Dumper($alloptions);

    
#    if( $returningoptions{help} )
#    {
#        if( $current_package_is_module )
#        {
#            delete $$default{configfilename};
#            delete $$default{debug};
#            delete $$default{help};
#        }
#        warn "[$packagename] ".($currentpackagename eq 'main'?'':'module')." options are :\n\t",join("\n\t",map(sprintf("--%-30s default: %s%s",$_.' ('.${$$default{$_}}[-1].')',${$$default{$_}}[0],($returningoptions{$_} ne ${$$default{$_}}[0]?sprintf("\n\t%-32s current: %s",'',$returningoptions{$_}):'')),sort keys  %{$default}))."\n";
#        exit if $currentpackagename eq 'main' ;
#    }
#    }


	return %{$all_options_merged};
}



sub readGetOptionsFromCommandline
{
    my($packagename_prefix,@getoptions) = @_;
    
    my %real_commandline_arguments;
    my @ARGVCOPY = @ARGV;
    Getopt::Long::Configure('pass_through');
    GetOptions(    \%real_commandline_arguments, @getoptions );
    @ARGV = @ARGVCOPY;

    #JNX::JLog::error "pkg: $packagename_prefix read:".Data::Dumper->Dumper(%real_commandline_arguments);
    my $returnhash;
    
    while( my($key,$value) = each %real_commandline_arguments )
    {
        #JNX::JLog::error "pkg:$packagename_prefix key:$key value: $value";
    
        $key =~ s/^\Q$packagename_prefix\E//i if $packagename_prefix ne 'main';
        $$returnhash{$key} = $value if length $key;
    }
    #JNX::JLog::error "\$returnhash:".Data::Dumper->Dumper($returnhash);
    return $returnhash;
}

sub maximum
{
    my ($a,$b) = @_;
    return $a > $b ? $a : $b;
}
sub minimum
{
    my ($a,$b) = @_;
    return $a < $b ? $a : $b;
}


1;
