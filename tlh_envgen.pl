#!/usr/bin/perl
$thisDir=( $0 =~ /^(.+)\// )? $1 : '.';
print "DEBUG: thisDir=\"$thisDir\"\n";
require "$thisDir/env_functions.pl";

=pod
tlh_envgen.pl -conf 20160509-1.3-hpcc.cfg test-wssql-environment.xml &> test-wssql-tlh_envgen.log
tlh_envgen.pl -conf 160513-two-thor-one-roxie-hpcc.cfg 160513-two-thor-one-roxie-hpcc.xml &> 160513-two-thor-one-roxie-hpcc-tlh_envgen.log
tlh_envgen.pl -conf thor-and-roxie-hpcc.cfg thor-and-roxie-hpcc.xml &> thor-and-roxie-hpcc-tlh_envgen.log
tlh_envgen.pl -conf two-thor-hpcc.cfg two-thor-hpcc-environment.xml &> two-thor-hpcc-tlh_envgen.log
tlh_envgen.pl -conf 20160510-1.2-hpcc.cfg 20160510-1.2-environment.xml &> 20160510-1.2-tlh_envgen.log
tlh_envgen.pl -conf 20160509-1.3-hpcc.cfg 20160509-1.3-environment.xml &> 20160509-1.3-tlh_envgen.log
tlh_envgen.pl -conf 20160509-1.2-hpcc.cfg 20160509-1.2-environment.xml &> 20160509-1.2-tlh_envgen.log
tlh_envgen.pl -conf 20160509-1-hpcc.cfg 20160509-1-environment.xml &> 20160509-tlh_envgen.log
tlh_envgen.pl -conf 20160507-2-hpcc.cfg 20160509-1-environment.xml &> 20160509-tlh_envgen.log
tlh_envgen.pl -conf 20160507-2-hpcc.cfg new_20160507-2-environment.xml &> 20160507-tlh_envgen.log
tlh_envgen.pl -conf rbi_hpcc.cfg new_10.60.0.14-20160503-environment.xml
=cut

#================== Get Arguments ================================
require "newgetopt.pl";
if ( ! &NGetOpt(
		"conf=s"
                ))      # Add Options as necessary
{
  print STDERR "\n[$0] -- ERROR -- Invalid/Missing options...\n\n";
  exit(1);
}
$configfile= $opt_conf || die "Usage ERROR: $0 -conf <hpcc configuration filename> (REQUIRED)\n";
print "configfile=\"$configfile\"\n";
#===============END Get Arguments ================================

# Directories to source templates
$change_source="$thisDir/environment-templates/frequently-changed-portions";
$unchange_source="$thisDir/environment-templates/unchanged-portions";

$infile = shift @ARGV;
$new_environment=( $infile=~/^(.+)\.xml$/ )? $1 : $infile ;
print "new_environment=\"$new_environment\"\n";

getHPCCConfiguration($configfile);
print "Number of IPs is ",scalar(keys %ip),". Number of THORs is ",scalar(@thor),". Number of ROXIEs is ",scalar(@roxie),".Number of support functions is ",scalar(@support),".\n";

#------------------------------------------------------------------------------------------------------------
# 1. cp -r $unchange_source $new_environment
if ( -e $new_environment ){
   die "New directory, $new_environment, already EXISTS. Must delete before proceduring. EXITING.\n";
}
print("cp -r $unchange_source $new_environment\n");
system("cp -r $unchange_source $new_environment");

#------------------------------------------------------------------------------------------------------------
# 2. Fill new_environment/Environment/Hardware with $change_source/Hardware/Computer attributes -- one for each
#   instance in the hpcc configuration file. The 1st will be named Computer. Each one after the 1st will be named
#   Computer#999, where 999 is sequential number starting with 1. Each Computer has 2 parameters to be filled in
#   from information in the hpcc_configuratin file, i.e. COMPUTER_NAME and COMPUTER_IP_ADDRESS. (these will be
#   private IPs).

 # Add Computer to $new_environment/Environment/Hardware
 foreach my $ip (keys %ip){
    my $pc_name=$pc_name{$ip};

   $_=`cat $change_source/Hardware/Computer`;
   s/{COMPUTER_NAME}/$pc_name/sg;
   s/{COMPUTER_IP_ADDRESS}/$ip/sg;
   print "saveFile\(\$_,\"\$new_environment/Environment/Hardware/Computer\"\)\;\n";
   saveFile($_,"$new_environment/Environment/Hardware/Computer");
 }

#------------------------------------------------------------------------------------------------------------
# 3. In new_environment/Environment/Software/DafilesrvProcess, for each computer placed in Hardware, above,
#     add $change_source/Software/DafilesrvProcess/Instance and $change_source/Software/FTSlaveProcess/Instance. Fill
#     in COMPUTER_NAME and COMPUTER_IP_ADDRESS in each.

 # Add Instance to $new_environment/Environment/Software/DafilesrvProcess and FTSlaveProcess
 #  for each computer
 my $i=1;
 foreach my $ip (keys %ip){
   my $pc_name=$pc_name{$ip};
   my $number=sprintf "%d", $i;

   $_=`cat $change_source/Software/DafilesrvProcess/Instance`;
   s/{NUMBER}/$number/sg;
   s/{COMPUTER_NAME}/$pc_name/sg;
   s/{COMPUTER_IP_ADDRESS}/$ip/sg;
   print "saveFile\(\$_,\"\$new_environment/Environment/Software/DafilesrvProcess/Instance\"\)\;\n";
   saveFile($_,"$new_environment/Environment/Software/DafilesrvProcess/Instance");

   $_=`cat $change_source/Software/FTSlaveProcess/Instance`;
   s/{NUMBER}/$number/sg;
   s/{COMPUTER_NAME}/$pc_name/sg;
   s/{COMPUTER_IP_ADDRESS}/$ip/sg;
   print "saveFile\(\$_,\"\$new_environment/Environment/Software/FTSlaveProcess/Instance\"\)\;\n";
   saveFile($_,"$new_environment/Environment/Software/FTSlaveProcess/Instance");
   $i++;
 }
#------------------------------------------------------------------------------------------------------------
# 4. The table below shows 1) where in new_environment/Environment/Software we must add one Instance, 2) where
#    that Instance should come from in $change_source/Software, and 3) where, in hpcc configuration, to get the 
#    COMPUTER_NAME and COMPUTER_IP_ADDRESS of the added Instance. If any of the components of column 3 is NOT
#    in the hpcc configuration file then the default for the Instance parameters will be master.
#   
# TARGET               SOURCE                 COMPONENT 
$component_table=<<EOFF;
DaliServerProcess      DaliServerProcess      dali
DfuServerProcess       DfuServerProcess       dfu
EclAgentProcess        EclAgentProcess        eclagent
EclCCServerProcess     EclCCServerProcess     eclcc
EclSchedulerProcess    EclSchedulerProcess    eclsch
EspProcess             EspProcess             esp
SashaServerProcess     SashaServerProcess     sasha
EOFF

@component_table=split(/\n/,$component_table);
foreach (@component_table){
  my ( $ip, $pc_name );
  my ($target, $source, $component)=split(/\s+/,$_);


  my ($ptr,$ip,$pc_name);
  if ( ! inSupport($component) ){
      die "FATAL ERROR: component=\"$component\" NOT is configuration file, \"$configfile\". EXITING\n";
  }
  else{
    $ptr=inSupport($component);
    $ip=$ptr->{ip};
    $pc_name=$pc_name{$ip};
  }

  print "DEBUG: Support function. component=\"$component\", pc_name=\"$pc_name\", ip=\"$ip\"\n";

  $source="$change_source/Software/$source/Instance";
  $target="$new_environment/Environment/Software/$target/Instance";
  $_=`cat $source`;
  s/{COMPUTER_NAME}/$pc_name/sg;
  s/{COMPUTER_IP_ADDRESS}/$ip/sg;
  print "saveFile\(\$_,$target\)\;\n";
  saveFile($_,$target);
}
#------------------------------------------------------------------------------------------------------------
# 5. In new_environment/Environment/Software, add $change_source/Software/DropZone. Fill in COMPUTER_NAME with the name
#    of the drop zone in the hpcc configuration file. If none there, give it the name of the master.

my $source="$change_source/Software/DropZone";
my $target="$new_environment/Environment/Software/DropZone";
my $ptr=inSupport('dropzone');
my $ip=$ptr->{ip};
my $pc_name=$pc_name{$ip};
print "DEBUG: Adding DropZone. ip=$ip, pc_name=\"$pc_name\"\n";
$_=`cat $source`;
s/{COMPUTER_NAME}/$pc_name/g;
print "saveFile\(\$_,$target\)\;\n";
saveFile($_,$target);
#------------------------------------------------------------------------------------------------------------
# 6. If there is a roxie defined in hpcc configuration file then copy the RoxieCluster structure by doing the following command:
#
#      cp -r $change_source/Software/RoxieCluster new_environment/Environment/Software
#
#    In the RoxieCluster, there are 2 attributes that need to be duplicated for each roxie instance in hpcc configuration.
#    These are RoxieFarmProcess and RoxieServerProcess. For RoxieFarmProcess, there are 2 parameters: FARM_NUMBER and FARM_PORT.
#    FARM_NUMBER will be a sequential number starting with 1. And, FARM_PORT will be 9876 if FARM_NUMBER is 1. Otherwise
#    it will be 0.
#    
#    The 2 parameters of RoxieFarmProcess that need to be modified are: COMPUTER_NAME and COMPUTER_IP_ADDRESS.
print "DEBUG: ============================== Number of ROXIEs is ",scalar(@roxie)," ==============================\n";
if ( scalar(@roxie) > 0 ){
  foreach my $roxie (@roxie){
    my $roxie_name=$roxie->{name};
    my @ip=@{$roxie->{roxie_ips}};
print "DEBUG: roxie_name=\"$roxie_name\", ROXIE IPs=(",join(",",@ip),")\n";
    # Copy RoxieCluster in $new_environment
    my $RoxieCluster=my_mkdir("$new_environment/Environment/Software/RoxieCluster");
    system("cp -r $change_source/Software/RoxieCluster/* $RoxieCluster");

    # Remove template RoxieFarmProcess and RoxieServerProcess
    system("rm $RoxieCluster/ahead $RoxieCluster/RoxieFarmProcess $RoxieCluster/RoxieServerProcess");
    # Get header from source
    my $_=`cat $change_source/Software/RoxieCluster/ahead`;
    s/{ROXIE_NAME}/$roxie_name/gs;
    print "saveFile\(\$_,\"$RoxieCluster/ahead\"\)\;\n";
    saveFile($_,"$RoxieCluster/ahead");

    for ( my $i=0; $i < scalar(@ip); $i++){
      my $farm_number=sprintf "%d",$i+1;
      my $ip=$ip[$i];
      my $pc_name=$pc_name{$ip};;
      my $farm_source="$change_source/Software/RoxieCluster/RoxieFarmProcess";
      my $server_source="$change_source/Software/RoxieCluster/RoxieServerProcess";
      my $farm_xml=`cat $farm_source`;
      my $server_xml=`cat $server_source`;
print "DEBUG: ROXIE PROCESSING. farm_number=\"$farm_number\", ip=\"$ip\", pc_name=\"$pc_name\", roxie_name=\"$roxie_name\"\n";    
      $_=$farm_xml;
      s/{FARM_NUMBER}/$farm_number/gs;
      my $port = ( $i==0 )? 9876 : 0 ;
      s/{FARM_PORT_NUMBER}/$port/s;
      print "saveFile\(\$_,\"$RoxieCluster/RoxieFarmProcess\"\)\;\n";
      saveFile($_,"$RoxieCluster/RoxieFarmProcess");

      if ( scalar(@ip)==1 ){
        my $farm_number=sprintf "%d",$i+2;
        $_=$farm_xml;
        s/{FARM_NUMBER}/$farm_number/gs;
        my $port = 0 ;
        s/{FARM_PORT_NUMBER}/$port/s;
        print "saveFile\(\$_,\"$RoxieCluster/RoxieFarmProcess\"\)\;\n";
        saveFile($_,"$RoxieCluster/RoxieFarmProcess");
      }
   
      $_=$server_xml;
      s/{COMPUTER_NAME}/$pc_name/sg;
      s/{COMPUTER_IP_ADDRESS}/$ip/sg;
      print "saveFile\(\$_,\"$RoxieCluster/RoxieServerProcess\"\)\;\n";
      saveFile($_,"$RoxieCluster/RoxieServerProcess");
    }
  }
}

THORPROCESS:
#------------------------------------------------------------------------------------------------------------
# 7. Process all THOR Clusters
print "DEBUG: ============================== Number of THORs is ",scalar(@thor)," ==============================\n";
if ( scalar(@thor) > 0 ){
  foreach my $thor (@thor){
    my $thor_name=$thor->{name};
    my $master_ip=$thor->{master_ip};
    my $master_pc_name=$pc_name{$master_ip};
    my @slave_ip=@{$thor->{slave_ips}};
print "DEBUG: thor_name=\"$thor_name\", THOR IPs=(",join(",",@slave_ip),")\n"; 

    # Copy ThorCluster in $new_environment
    my $ThorCluster=my_mkdir("$new_environment/Environment/Software/ThorCluster");
    system("cp -r $change_source/Software/ThorCluster/* $ThorCluster");

    # Remove template any files from $change_source ThorCluster
    print("rm $ThorCluster/ahead $ThorCluster/ThorMasterProcess $ThorCluster/ThorSlaveProcess\n");
    system("rm $ThorCluster/ahead $ThorCluster/ThorMasterProcess $ThorCluster/ThorSlaveProcess");
    
    # To ahead add MASTER_COMPUTER_NAME and THOR_NAME
    my $ahead_source="$change_source/Software/ThorCluster/ahead";
    $_=`cat $ahead_source`;
    s/{MASTER_COMPUTER_NAME}/$master_pc_name/s;
    s/{THOR_NAME}/$thor_name/s;
    print "saveFile\(\$_,\"$ThorCluster/ahead\"\)\;\n";
    saveFile($_,"$ThorCluster/ahead");
    
    # To ThorMasterProcess add MASTER_COMPUTER_NAME
    my $ThorMasterProcess_source="$change_source/Software/ThorCluster/ThorMasterProcess";
    $_=`cat $ThorMasterProcess_source`;
    s/{MASTER_COMPUTER_NAME}/$master_pc_name/s;
    print "saveFile\(\$_,\"$ThorCluster/ThorMasterProcess\"\)\;\n";
    saveFile($_,"$ThorCluster/ThorMasterProcess");

    # For each slave ip add ThorSlaveProcess and set COMPUTER_NAME and SLAVE_NUMBER
    for ( my $i=0; $i < scalar(@slave_ip); $i++){
      my $slave_number=sprintf "%03d",$i+1;
      my $slave_ip=$slave_ip[$i];
      my $pc_name=$pc_name{$slave_ip};;
      my $ThorSlaveProcess_source="$change_source/Software/ThorCluster/ThorSlaveProcess";
      my $ThorSlaveProcess_xml=`cat $ThorSlaveProcess_source`;
print "DEBUG: THOR PROCESSING. slave_number=\"$slave_number\", slave_ip=\"$slave_ip\", pc_name=\"$pc_name\", thor_name=\"$thor_name\"\n";    
      $_=$ThorSlaveProcess_xml;
      s/{SLAVE_NUMBER}/$slave_number/gs;
      s/{COMPUTER_NAME}/$pc_name/s;
      print "saveFile\(\$_,\"$ThorCluster/ThorSlaveProcess\"\)\;\n";
      saveFile($_,"$ThorCluster/ThorSlaveProcess");
    }
  }
}

#------------------------------------------------------------------------------------------------------------
# 8. Modifying Topology, in new_environment/Environment/Software:
#    if there is a thor then 
#       mkdir Topology/Cluster & cp $change_source/Software/Topology/Cluster/ahead_thor to Topology/Cluster/ahead
#       and take from $change_source/Software/Topology/Cluster these 3 attributes EclAgentProcess, EclCCServerProcess, and
#       EclSchedulerProcess. Also for each THOR take one ThorCluster attribute and replace {THOR_NAME} with the thor name
#       (default if only one thor is mythor).
#    if there is a roxie then 
#       mkdir Cluster & cp $change_source/Software/Topology/Cluster/ahead_roxie to Topology/Cluster/ahead
#       and take from $change_source/Software/Topology/Cluster these 3 attributes EclCCServerProcess, EclSchedulerProcess, and
#       RoxieCluster.

print "Size of \@thor is ",scalar(@thor),"\n";
if ( scalar(@thor) > 0 ){
  print "my_mkdir(\"$new_environment/Environment/Software/Topology/Cluster\")\n";
  my $target_path=my_mkdir("$new_environment/Environment/Software/Topology/Cluster");
  print "target_path=\"$target_path\"\n";
  system("cp $change_source/Software/Topology/Cluster/ahead_thor $target_path/ahead");
  system("cp $change_source/Software/Topology/Cluster/EclAgentProcess $target_path");
  system("cp $change_source/Software/Topology/Cluster/EclCCServerProcess $target_path");
  system("cp $change_source/Software/Topology/Cluster/EclSchedulerProcess $target_path");
  foreach my $thor (@thor){
     my $thor_name=$thor->{name};
print "DEBUG: In foreach. thor_name\"$thor_name\"\n";
     my $source="$change_source/Software/Topology/Cluster/ThorCluster";
     $_=`cat $source`;
     chomp;
     s/{THOR_NAME}/$thor_name/gs;
     print "saveFile\(\$_,\"$target_path/ThorCluster\"\)\; Length of ThorCluster is ",length($_),"\n";
     saveFile($_,"$target_path/ThorCluster");
  }
}

print "Size of \@roxie is ",scalar(@roxie),"\n";
if ( scalar(@roxie) > 0 ){
  print "my_mkdir(\"$new_environment/Environment/Software/Topology/Cluster\")\n";
  my $target_path=my_mkdir("$new_environment/Environment/Software/Topology/Cluster");
  print "target_path=\"$target_path\"\n";
  system("cp $change_source/Software/Topology/Cluster/ahead_roxie $target_path/ahead");
  system("cp $change_source/Software/Topology/Cluster/EclCCServerProcess $target_path");
  system("cp $change_source/Software/Topology/Cluster/EclSchedulerProcess $target_path");
  foreach my $roxie (@roxie){
     my $roxie_name=$roxie->{name};
print "DEBUG: In foreach. roxie_name\"$roxie_name\"\n";
     my $source="$change_source/Software/Topology/Cluster/RoxieCluster";
     $_=`cat $source`;
     chomp;
     s/{ROXIE_NAME}/$roxie_name/gs;
     print "saveFile\(\$_,\"$target_path/RoxieCluster\"\)\; Length of RoxieCluster is ",length($_),"\n";
     saveFile($_,"$target_path/RoxieCluster");
  }
}

#------------------------------------------------------------------------------------------------------------
# 9. If wssql exists, then 1) add its BuildSet to Programs/Build, 2) add EspBinding to EspProcess and add
#    its EspService to Software.
if ( inSupport('wssql') ){
  print "DEBUG: FOUND WSSQL. First add its BuildSet to Environment/Programs/Build.\n";
  # Add its BuildSet to Programs/Build
  $_=`cat $change_source/Programs/Build/BuildSet#wssql`;
  print "saveFile\(\$_,\"\$new_environment/Environment/Programs/Build/BuildSet\"\)\;\n";
  saveFile($_,"$new_environment/Environment/Programs/Build/BuildSet");

  # Add its EspService to Software
  print "DEBUG: FOUND WSSQL. Second, add its EspService to Environment/Software.\n";
  $_=`cat $change_source/Software/EspService#wssql`;
  print "saveFile\(\$_,\"\$new_environment/Environment/Software/EspService\"\)\;\n";
  saveFile($_,"$new_environment/Environment/Software/EspService");

  # Add EspBinding to EspProcess
  print "DEBUG: FOUND WSSQL. Thrid, add its EspBinding to Environment/Software/EspProcess.\n";
  $_=`cat $change_source/Software/EspProcess/EspBinding#wssql`;
  print "saveFile\(\$_,\"\$new_environment/Environment/Software/EspProcess/EspBinding\"\)\;\n";
  saveFile($_,"$new_environment/Environment/Software/EspProcess/EspBinding");
}

#------------------------------------------------------------------------------------------------------------
# A. If there are assignment statements like the following:
#     
#     Software.ThorCluster.ahead:slavesPerNode="4"
#     
#     Then do the following:
#     1. my ( $path, $assignment )=split(/:/,$_); # where assignment statement is in $_
#     2. $path =~ s/\./\//g;
#     3. $path = "$new_environment/Environment/$path";
#     4. $_=`cat $path`;
#     5. my $re = $assignment;
#     6. $re =~ s/=".+"/=".\+"/;
#     7. s/\b$re/$assignment/;
#     8. saveFile($_,$path);

print "===================== ASSIGNMENTs =====================\n";
if (scalar(@thor)==1){
   my $master_ip=$thor[0]->{master_ip};
   my $slave_ip=@{$thor[0]->{slave_ips}}[0];
}
for ( my $i=0; $i < scalar(@assignment); $i++){
     my $path=$assignment[$i]->{path};
     my $assignments=$assignment[$i]->{assignments};

     $path =~ s/\./\*\//g;
     $path = "$new_environment/Environment/$path";
     $path = "$path $path#*" if -e "$path#*";
print "DEBUG: In ASSIGNMENT. Just before 'ls -1 \$path' path=\"$path\"\n";
     my $paths = `ls -1 $path`;
     my @path=split(/\n/,$paths);
     @path=grep(!/cannot access/,@path); # remove access errors
     @path=grep(!/cannot access/,@path); # remove errors
print "DEBUG: In ASSIGNMENT. \@path=(",join(",",@path),")\n";

     foreach my $path (@path){
print "DEBUG: In ASSIGNMENT. In foreach \@path loop. path=\"$path\"\n";
       $path = "$path/ahead" if -d $path; # e.g. assignment: Software.ThorCluster:slavesPerNode="4" (assignment will be in ahead)
       $_=`cat $path`; 
       foreach my $assignment (@$assignments){
print "DEBUG: In ASSIGNMENT. foreach \@assignment loop. assignment=\"$assignment\"\n";
	 my ( $parm, $value )=split(/=/,$assignment);
         my $re = '\b'.$parm.'=".*?"';
       
	 # ASSIGNMENT FOUND
         if ( s/$re/$assignment/s ){
           print "ASSIGNMENT FOUND.\n";
         }
	 # ASSIGNMENT NOT FOUND
         elsif( /(\n +)([a-zA-Z]\w*="[^"]+")(\/?\>)/s ){
	   my $indent=$1;
	   my $a=$2;
	   my $endtag=$3;
print "DEBUG: In ASSIGNMENT. ASSIGNMENT NOT FOUND. indent=\"$indent\", a=\"$a\", endtag=\"$endtag\"\n";
	   my $new_assignment="$indent$a$indent$assignment$endtag";
	   s/\n +[a-zA-Z]\w*="[^"]+"\/?\>/$new_assignment/s;
print "DEBUG: In ASSIGNMENT. Just before saveFile. new_assignment=\"$new_assignment\"\n";
           print "ASSIGNMENT NOT FOUND. New tail is \"".substr($_,length($_)-60)."\"\n";
         }
         else{
           die "ERROR: ASSIGNMENT. Did not add assignment, \"$assignment\" at path=\"$path\"\n";
         }
       }

       print "ASSIGNMENT.  AFTER FOREACH \@ASSIGNMENT LOOP. saveFile\(\$_,$path\)\;\n";
       saveFile($_,$path, 'skipunique');
     }
}

OUTPUTXMLFILE:
#------------------------------------------------------------------------------------------------------------
# A. Make environment.xml file from $new_environment
print(" $thisDir/NestedFolders2ENV.pl $new_environment.xml \> NestedFolders2ENV-$new_environment.log\n");
system("$thisDir/NestedFolders2ENV.pl $new_environment.xml > NestedFolders2ENV-$new_environment.log");
