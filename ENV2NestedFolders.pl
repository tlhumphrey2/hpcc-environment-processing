#!/usr/bin/perl
$thisDir=( $0 =~ /^(.+)\// )? $1 : '.';
print "DEBUG: thisDir=\"$thisDir\"\n";
require "$thisDir/env_functions.pl";

=pod
ENV2NestedFolders.pl two-thor-one-roxie-template-environment.xml > ENV2NestedFolders.log
ENV2NestedFolders.pl 20160421-newly_created_environment.xml|less
ENV2NestedFolders.pl -s "node000115!10.0.0.115" 20160420-environment.xml|less
ENV2NestedFolders.pl 20160420-environment.xml|less
ENV2NestedFolders.pl 20160420-newly_created_environment.xml|less
ENV2NestedFolders.pl 52.33.221.178-environment.xml|less
=cut

#================== Get Arguments ================================
require "newgetopt.pl";
if ( ! &NGetOpt(
                "search=s"
                ))      # Add Options as necessary
{
  print STDERR "\n[$0] -- ERROR -- Invalid/Missing options...\n\n";
  exit(1);
}
$search = $opt_search;
if ( $search !~ /^\s*$/ ){
   @search=split(/\^/,$search);
   print "\@search=(",join(", ",@search),")\n";
}
#===============END Get Arguments ================================


$infile = shift @ARGV;
$basename = ($infile=~/^(.+)\.xml$/)? $1 : "${infile}_dir" ;
if ( -e $basename ){
  die "FALAL ERROR: Directory, $basename , EXISTS. MUST DELETE BEFORE PROCEEDING. EXITING.\n";
}
else{
  print("mkdir $basename\n");
}
system("mkdir $basename");

$_=`cat $infile`;
print "DEBUG: Size of file is ",length($_),"\n";

$one_level='.';

local @line = split(/\n/, $_);
ENV2NestedFolders($basename, '', '', '', 0, $#line);
#================================================================
sub ENV2NestedFolders{
my ( $CurrentDir, $indent, $parent_path, $parent, $parent_begin, $parent_end )=@_;
print "DEBUG: Entering ENV2NestedFolders. CurrentDir=\"$CurrentDir\", parent=\"$parent\", parent_path=\"$parent_path\", parent_begin=$parent_begin, parent_end=$parent_end, line\[parent_begin]=\"$line[$parent_begin]\"\n";

  my $begin=$parent_begin+1;
  my $end=(($parent_begin!=$parent_end) && ($line[$parent_end]=~/\<\/$parent>/))? $parent_end-1 : $parent_end ;
  my ($rname, $rbegin, $rend)=getAllCurrentLevelAttributes($indent, $parent, $begin, $end);
print "DEBUG: In ENV2NestedFolders. Just after call to getAllCurrentLevelAttributes parent=\"$parent\", Number of Attributes is ",scalar(@$rname),"\n";

  if ($parent ne ''){
    if ( scalar(@$rname) > 0 ) {
print "DEBUG: In ENV2NestedFolders. parent=\"$parent\" HAS CHILDREN. Making CurrentDir=\"$CurrentDir\"\n";
       $CurrentDir = my_mkdir($CurrentDir);

       if ( $line[$parent_begin]=~/^ *<$parent / ){
         my $ahead=getHead($parent, $parent_begin, $parent_end);
         if ( length($ahead) > 0 ){
print "DEBUG: In ENV2NestedFolders. parent=\"$parent\" HAS CHILDREN AND HEAD whose length is ",length($ahead),"\n";
            saveFile($ahead,"$CurrentDir/ahead");
         }
       }
    }
    # Found attribute that has NO children. So save it it current
    else{
print "DEBUG: In ENV2NestedFolders. parent=\"$parent\" HAS NO CHILDREN.\n";
       my $xml=join("\n",@line[$parent_begin .. $parent_end]);
       saveFile($xml, $CurrentDir);
    }
  }

  for( my $i=0; $i < scalar(@$rname); $i++){
    my $cname = $rname->[$i];
    my $cbegin = $rbegin->[$i];
    my $cend = $rend->[$i];
    print "$indent$cname\n";
print "DEBUG: In ENV2NestedFolders. In For LOOP. i=$i, cname=\"$cname\", cbegin=\"$cbegin\", cend=\"$cend\"\n";
    my $path=($parent_path eq '')? $cname : "$parent_path/$cname" ;
    ENV2NestedFolders("$CurrentDir/$cname", "$indent ", $path, $cname, $cbegin, $cend);
print "DEBUG: In ENV2NestedFolders. Return from parseENV. i=$i, parent=\"$cname\", path=\"$path\", parent_begin=",$cbegin,", parent_end=",$cend,"\n";
  }
}
#================================================================
sub getAllCurrentLevelAttributes{
my ( $indent, $parent, $parent_begin, $parent_end)=@_;
print "DEBUG: Entering getAllCurrentLevelAttributes. indent=\"$indent\", parent=\"$parent\", parent_begin=$parent_begin, parent_end=$parent_end\n";
   my (@name, @begin, @end);
   my $first=1;
   my $prev_name='';
   for ( my $i=$parent_begin; $i <= $parent_end; $i++){
     my ($name, $begin, $end);
     if ( $line[$i] =~ /^$indent\<(\w+)\b/ ){
       push @name, $1;
       push @begin, $i;
       push @end, $i-1 if ! $first;
print "DEBUG: In getAllCurrentLevelAttributes. name=\"$1\", begin=\"$i\"\n";
       $first=0;
     }
   }
   push @end, $parent_end;
for( my $i=0; $i < scalar(@name); $i++){
print "DEBUG: Leaving getAllCurrentLevelAttributes. name=$name[$i], begin=$begin[$i], end=$end[$i]\n";
}
return (\@name,\@begin,\@end);
}
#================================================================
sub getHead{
my ($aname, $abegin, $aend)=@_;
print "DEBUG: Entering getHead. aname=\"$aname\", abegin=\"$abegin\", aend=\"$aend\"\n";
  my $ahead='';
  my @aline=();

return $ahead if $abegin == $aend; # NO HEAD EXISTS

  for ( my $i=$abegin; $i <= $aend; $i++){
      push @aline, $line[$i];
      last if $line[$i] =~ /^[^>]+[^\/]>\s*$/;
  }

  $ahead = join("\n",@aline);

return $ahead;
}
