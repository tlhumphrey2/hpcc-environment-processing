#!/usr/bin/perl
$thisDir=( $0 =~ /^(.+)\// )? $1 : '.';
require "$thisDir/env_functions.pl";

=pod
test-getHPCCConfiguration.pl -conf 20160509-1.3-hpcc.cfg
test-getHPCCConfiguration.pl -conf 20160509-1-hpcc.cfg
test-getHPCCConfiguration.pl -conf 20160507-2-hpcc.cfg
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


getHPCCConfiguration($configfile);
print "Number of IPs is ",scalar(keys %ip),". Number of THORs is ",scalar(@thor),". Number of ROXIEs is ",scalar(@roxie),".Number of support functions is ",scalar(@support),".\n";

print "----------------------------- \%pc_name -----------------------------\n";
foreach my $t (sort keys %pc_name){
   print "  $t	\"$pc_name{$t}\"\n";
}
print "----------------------------- \@thor -----------------------------\n";
foreach my $t (@thor){
   print "  name=\"$t->{name}\"\n";
   print "  master_ip=\"$t->{master_ip}\"\n";
   print "  slave ips:\n";
   my @ip=@{$t->{slave_ips}};
   foreach (@ip){
      print "    $_	\"$pc_name{$_}\"\n";
   }
}
print "----------------------------- \@roxie -----------------------------\n";
foreach my $t (@roxie){
   print "  name=\"$t->{name}\"\n";
   print "  roxie ips:\n";
   my @ip=@{$t->{roxie_ips}};
   foreach (@ip){
      print "    $_	\"$pc_name{$_}\"\n";
   }
}
print "----------------------------- \@support -----------------------------\n";
foreach my $t (@support){
   print "  ip=\"$t->{ip}\"	name=\"$t->{name}\"	pc_name=\"$pc_name{$t->{ip}}\"\n";
}
print "----------------------------- \@assignment -----------------------------\n";
foreach my $t (@assignment){
   print "  path=\"$t->{path}\"\n";
   my @assignment=@{$t->{"assignments"}};
   foreach (@assignment){
      print "    assignment=\"$_\"\n";
   }
}
