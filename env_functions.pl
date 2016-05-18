#!/usr/bin/perl
# DATA Structures for saving this info
#  @thor, array of THORs, where each entry has:
#    name
#    master_ip
#    slave_ips
#  @roxie, array of ROXIEs, where each entry has:
#    name
#    roxie_ips
#  @support, all support functions, where each entry has:
#    supportname
#    ip
#  @assignment, array of assignment statements, where each entry has:
#    path, where assignment must be placed
#    parameter, name of parameter to be set
#    value, assigned value of parameter
#  %pc_name, hash where key is ip and value is computer name
#
=pod
EXAMPLE hpcc configuration file
thor names are: thor1,thor2
roxie names are: roxie1

#  IPs          PC NAMES    COMPONENTS
   10.60.0.11	tm1	    master:thor1
   10.60.0.14	ts11	    slave:thor1
   10.60.0.116	ts12	    slave:thor1

   10.60.0.30	tm2	    master:thor2
   10.60.0.240	ts21	    slave:thor2
   10.60.0.249	ts22	    slave:thor2

   10.60.0.63	rx11	    roxie:roxie1
   10.60.0.124	rx12	    roxie:roxie1
   10.60.0.111	middleware  dali
   10.60.0.111	middleware  dfu
   10.60.0.111	middleware  eclagent
   10.60.0.111	middleware  eclcc
   10.60.0.111	middleware  eclsch
   10.60.0.111	middleware  esp
   10.60.0.111	middleware  sasha
   10.60.0.11	tm1	    dropzone
   
Software.ThorCluster.ahead:slavesPerNode="4"
Software.ThorCluster.ahead:globalMemorySize="14000"
=cut
sub getHPCCConfiguration{
my ($configfile)=@_;
my @support_name=(dali,dfu,eclagent,eclcc,eclsch,esp,sasha,dropzone);
my $support_re='(?:(?i)\b(?:'.join("|",@support_name).')\b)';
my %roxie_seen=();
my %thor_seen=();
my $support_default_computer;
my $ptr; # This is a undefined reference pointer

# Get contents of $configfile
  $_=`cat $configfile`;
  @line=split(/\n/,$_);
  
  my @thorname = ("mythor"); # default thor name
  my @roxiename = ("myroxie"); # default roxie name
  foreach (@line){
    next if /^\s*#/ || /^\s*$/; #skip comments and blank lines
    if ( /^\s*thor names are:/i ){
       my $names = $1 if /^\s*thor names are:\s*([a-zA-Z].*[a-zA-Z0-9_])\s*$/i;
       @thorname=split(/[\s,]+/,$names);
    }
    elsif ( /^\s*roxie names are:/i ){
       my $names = $1 if /^\s*roxie names are:\s*([a-zA-Z].*\w)\s*$/i;
       @roxiename=split(/[\s,]+/,$names);
    }
    # IP found a master, slave or roxie
    elsif ( /^\s*(\d+\.\d+\.\d+\.\d+)\s+(?:([a-zA-Z]\w+)\s+)?((?i)(?:master|slave|roxie))(?::([a-zA-Z]\w+))?/ ){
       my $ip=$1;
       my $computer_name=( $2 ne '' )? $2 : ($pc_name{$ip} ne '')? $pc_name{$ip} : sprintf "node%06d",(split(/\./,$ip))[3];
       my $hpcc_component=$3;
       my $component_name=( $4 ne '' )? $4 : ($hpcc_component eq 'roxie')? 'myroxie': 'mythor';
       my $named_components_re='(?:'.join("|",(@thorname,@roxiename)). ')';

       die "In getHPCCConfiguration. component_name=\"$component_name\" is NOT one given, i.e. (",join(",",(@thorname,@roxiename)),")\n" if $component_name!~/^$named_components_re$/;
    
       $ip{$ip}=1;
       $pc_name{$ip}=$computer_name;
       # This is ROXIE
       if ( $hpcc_component =~ /^roxie$/i ){
           if ( ! $roxie_seen{$component_name} ){
              $roxie_seen{$component_name}=1;
              my $ptr; @$ptr=($ip);
              push @roxie, entity("name"=>$component_name,"roxie_ips"=>$ptr);
           }
           else{
              foreach my $ptr (@roxie){
                 if ( $ptr->{"name"} eq $component_name ){
                    push @{$ptr->{"roxie_ips"}}, $ip;
                    last;
                 }
              }
           }
       }
       # This must be either master or slave of THOR
       else{
           my $thorptr; # This will be a pointer to this thor's entry
           if ( ! $thor_seen{$component_name} ){
              $thor_seen{$component_name}=1;
              my $ptr2; @$ptr2=($hpcc_component =~ /^master$/i)? () : ($ip);
              push @thor, entity("name"=>$component_name,"slave_ips"=>$ptr2);
              $thorptr = $thor[$#thor];
           }
           else{
              foreach  $thorptr (@thor){
                 if ( $thorptr->{"name"} eq $component_name ){
                    push @{$thorptr->{"slave_ips"}}, $ip;
                    last;
                 }
              }
           }

           if ( $hpcc_component =~ /^master$/i ){
              $thorptr->{master_ip}=$ip;
              $support_default_computer = $ip if $support_default_computer eq '';
           }
       }
    }
    # IP found of support function
    elsif ( /^\s*(\d+\.\d+\.\d+\.\d+)\s+((?:[a-zA-Z]\w+)?)\s+($support_re)/ ){
       my $ip=$1;
       my $computer_name=( $2 ne '' )? $2 : ($pc_name{$ip} ne '')? $pc_name{$ip} : sprintf "node%06d",(split(/\./,$ip))[3];
       my $component_name=$3;
       $ip{$ip}=1;
       $pc_name{$ip}=$computer_name;
       push @support, entity("name"=>$component_name,"ip"=>$ip);
    }
    # ASSIGNMENTs
    elsif( /^\s*((?:EnvSettings|Hardware|Programs|Software)(?:\.\w+)*):(\w+s*=\s*\".+")\s*$/ ){
       my $path=$1;
       my $assignment=$2;

       die "FATAL ASSIGNMENT ERROR: Assignment, \"$_\", is for ThorCluster but NO THORs in configuration." if ( ((scalar(@thor)==0) && ($path=~/Software\.ThorCluster/)) ); 
       die "FATAL ASSIGNMENT ERROR: Assignment, \"$_\", is for RoxieCluster but NO ROXIEs in configuration." if ( ((scalar(@roxie)==0) && ($path=~/Software\.RoxieCluster/)) ); 
       
       my $pathexists=inAssignments($path);

       if ( $pathexists ){
         push @{$pathexists->{"assignments"}}, $assignment;
       }
       else{
         push @assignment, entity("path"=>$path);
         push @{$assignment[$#assignment]->{"assignments"}}, $assignment;
         
       }
    }
  }
  
  # Handling missing support functions (i.e. they are not in hpcc configuration file). So, give them an IP address.
  if ( $support_default_computer eq '' ){
     if ( scalar(@roxie) > 0 ){
        my $ptr=$roxie[0];
	my @ip=@{$ptr->{"roxie_ips"}};
	$support_default_computer=$ip[0];
     }
     else{
        die "FATAL ERROR: configfile=\"$configfile\" DOES NOT HAVE THOR or ROXIE.\n";
     }
  }

  my @more_support=();
  foreach (@support_name){
     if ( ! inSupport($_) ){
       push @more_support, entity("name"=>$_,"ip"=> $support_default_computer);
     }
  }
  
  @support = (@support,@more_support);

  #---------------------------------------------------------------------------------------------------
  # Verify components: Each THOR component has an IP and multiple THORs have the same number instances
  #---------------------------------------------------------------------------------------------------
  if ( scalar(@thor) > 0 ){
    my $errors='';
    for( my $i=0; $i < scalar(@thor); $i++){
       local $_=$thor[$i];
       $errors .=" THOR\[",$i+1,"\] has NO name." if $_->{name} eq '';
       $errors .=" THOR\[",$i+1,"\]'s master has NO IP." if $_->{master_ip} eq '';
       my @slave_ip=@{$_->{slave_ips}};
       for( my $j=0; $j < scalar(@slave_ip); $j++){
          $errors .=" THOR\[",$i+1,"\] slave\[",$j+1,"\] has NO IP." if $slave_ip[$j] eq '';
       }
    }
    die "FATAL ERRORS: $errors\n" if $errors ne '';
  }
  if ( scalar(@thor) > 1 ){
     my $HaveDifferentSlaveNumbers=0;
     for( my $i=0; $i < scalar(@thor); $i++){
        for( my $j=1; $j < scalar(@thor); $j++){
	   if ( scalar(@{$thor[$i]->{slave_ips}}) != scalar(@{$thor[$j]->{slave_ips}}) ){
	     $HaveDifferentSlaveNumbers=1;
	     last;
	   }
        }
     }
     die "FATAL ERROR: Two or more THORs have different number of THOR slaves.\n" if $HaveDifferentSlaveNumbers;
  }

  #---------------------------------------------------------------------------------------------------
  # Verify components: Each ROXIE component has an IP and multiple ROXIEs have the same number instances
  #---------------------------------------------------------------------------------------------------
  if ( scalar(@roxie) > 0 ){
    my $errors='';
    for( my $i=0; $i < scalar(@roxie); $i++){
       local $_=$roxie[$i];
       $errors .=" ROXIE\[",$i+1,"\] has NO name." if $_->{name} eq '';
       my @roxie_ip=@{$_->{roxie_ips}};
       for( my $j=0; $j < scalar(@roxie_ip); $j++){
          $errors .=" ROXIE\[",$i+1,"\] slave\[",$j+1,"\] has NO IP." if $roxie_ip[$j] eq '';
       }
    }
    die "FATAL ERRORS: $errors\n" if $errors ne '';
  }
  if ( scalar(@roxie) > 1 ){
     my $HaveDifferentSlaveNumbers=0;
     for( my $i=0; $i < scalar(@roxie); $i++){
        for( my $j=1; $j < scalar(@roxie); $j++){
	   if ( scalar(@{$roxie[$i]->{roxie_ips}}) != scalar(@{$roxie[$j]->{roxie_ips}}) ){
	     $HaveDifferentSlaveNumbers=1;
	     last;
	   }
        }
     }
     die "FATAL ERROR: Two or more ROXIEs have different number of instances.\n" if $HaveDifferentSlaveNumbers;
  }
}
#-----------------------------------------------
sub inAssignments{
my ( $path )=@_;
   my $rc=0;
   foreach my $ptr (@assignment){
      if ( $ptr->{"path"} eq $path ){
         $rc=$ptr;
         last;
      }
   }
return $rc;
}
#-----------------------------------------------
sub inSupport{
my ( $in_support )=@_;
   my $rc=0;
   foreach my $ptr (@support){
      if ( $ptr->{"name"} eq $in_support ){
         $rc=$ptr;
         last;
      }
   }
return $rc;
}
#-----------------------------------------------
sub entity{
my ( %hash )=@_;
my $ptr;
  foreach my $key (keys %hash){
    $ptr->{$key}=$hash{$key};
  }
return $ptr;
}
#================================================================
sub my_mkdir{
my ( $dir )=@_;
  $dir=UniquePath($dir);
  mkdir $dir if ! -e $dir;
print "DEBUG: Leaving my_mkdir. dir=\"$dir\"\n";
return $dir;
}
#================================================================
sub UniquePath{
my ( $path )=@_;
#print "DEBUG: Entering UniquePath. path=\"$path\".\n";
#print "DEBUG: In UniquePath. Keys to \%PathExists are (",join("\n   DEBUG: In UniquePath. Keys to \%PathExists are ",keys %PathExists),").\n";
  $PathExists{$path}=1 if -e $path; # Need this in case $path exists but hasn't been seen by this code before
  if ( $PathExists{$path} ){
    $path = modifyName($path);
  }
  $PathExists{$path}=1;
print "DEBUG: Leaving UniquePath. path=\"$path\".\n";
return $path;
}
#================================================================
sub modifyName{
my ( $path )=@_;
#print "DEBUG: Entering modifyName. path=\"$path\".\n";
     while ( $PathExists{$path} ){
       my $n = ( $path =~ s/#(\d+)$// )? $1 : 0 ;
       $path = sprintf "%s#%03d", $path,$n+1;
#print "DEBUG: In modifyName. After mod. path=\"$path\".\n";
     }
     $PathExists{$path}=1;
#print "DEBUG: Leaving modifyName. path=\"$path\".\n";
 return $path;
}
#================================================================
sub saveFile{
my ( $xml, $FileFullPath, $skipunique )=@_;
chomp $xml; # remove ending linefeed
print "DEBUG: In saveFile. FileFullPath=\"$FileFullPath\".\n";
   if ( $skipunique eq '' ){
     $FileFullPath=UniquePath($FileFullPath) ;
print "DEBUG: In saveFile. After UniquePath FileFullPath=\"$FileFullPath\".\n";
   }
   open(OUT,">$FileFullPath") || die "Can't open for output \"$FileFullPath\"\n";
   print OUT $xml;
   close(OUT);
}
#================================================================
1;
