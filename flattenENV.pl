#!/usr/bin/perl
=pod
perl flattenENV.pl -s node000115^10.0.0.115^node000243^10.0.0.243^node000171^10.0.0.171 20160420-environment.xml|less
perl flattenENV.pl -s node000115^10.0.0.115^node000066^10.0.0.66^node000221^10.0.0.221 20160421-newly_created_environment.xml|less
perl flattenENV.pl 20160421-newly_created_environment.xml|less
perl flattenENV.pl -s "node000115!10.0.0.115" 20160420-environment.xml|less
perl flattenENV.pl 20160420-environment.xml|less
perl flattenENV.pl 20160420-newly_created_environment.xml|less
perl flattenENV.pl 52.33.221.178-environment.xml|less
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
$basename = ($infile=~/^(.+)\.xml$/)? $1 : $infile;

$_=`cat $infile`;
print "DEBUG: Size of file is ",length($_),"\n";

$one_level='.';

local @line = split(/\n/, $_);
local @AssignmentFullPath=();
flattenENV('', '', '', 0, $#line);
$asgnfile="$basename.asgn";
open(OUT,">$asgnfile") || die "Can't open for output \"$asgnfile\"\n";
print OUT join("\n",@AssignmentFullPath),"\n";
close(OUT);
print STDERR "Outputting: $asgnfile\n";
#================================================================
sub flattenENV{
my ( $indent, $parent_path, $parent, $parent_begin, $parent_end )=@_;
print "DEBUG: Entering flattenENV. parent=\"$parent\", parent_path=\"$parent_path\", parent_begin=$parent_begin, parent_end=$parent_end\n";
print "DEBUG: Entering flattenENV. First 30 characters of line\[$parent_begin\]=\"",substr($line[$parent_begin],0,30),"\"\n";

  if ( ($parent ne '') && ($line[$parent_begin]=~/^ *<$parent /) ){
    my @ThisAttributesAssignmentsFullPaths=getAllAssignmentFullPaths($parent_path, $parent, $parent_begin, $parent_end);
    push @AssignmentFullPath, @ThisAttributesAssignmentsFullPaths;
  }
  elsif ( ($parent ne '') && ($parent_begin==$parent_end) && ($line[$parent_begin]=~/<$parent>(.*)<\/$parent>/) ){
     my $value=$1;
     local $_=$parent_path;
     s/\.$parent$/:$parent/;
     $a="$_=\"$value\"";
     push @AssignmentFullPath, $a;
print "DEBUG: ONE LINE assignment is \"$a\". line\[$parent_begin\]=\"$line[$parent_begin]\"\n";
  }

  my $begin=( ($parent ne '') && ($parent_begin==$parent_end) )? $parent_begin : $parent_begin+1;
  my $end=( ($parent ne '') && ($parent_begin!=$parent_end) && ($line[$parent_end]=~/\<\/$parent>/))? $parent_end-1 : $parent_end ;
  my ($rname, $rbegin, $rend)=getAllCurrentLevelAttributes($indent, $parent, $begin, $end);
print "DEBUG: In flattenENV. Just after call to getAllCurrentLevelAttributes parent=\"$parent\", Number of Attributes is ",scalar(@$name),"\n";
  for( my $i=0; $i < scalar(@$rname); $i++){
    my $cname = $rname->[$i];
    my $cbegin = $rbegin->[$i];
    my $cend = $rend->[$i];
    print "$indent$cname\n";
print "DEBUG: In flattenENV. In For LOOP. i=$i, cname=\"$cname\", cbegin=\"$cbegin\", cend=\"$cend\"\n";
    my $path=($parent_path eq '')? $cname : "$parent_path.$cname" ;
   flattenENV("$indent ", $path, $cname, $cbegin, $cend);
print "DEBUG: In flattenENV. Return from flattenENV. i=$i, parent=\"$cname\", path=\"$path\", parent_begin=",$cbegin,", parent_end=",$cend,"\n";
  }
}
#================================================================
sub getAllCurrentLevelAttributes{
my ( $indent, $parent, $parent_begin, $parent_end)=@_;
print "DEBUG: Entering getAllCurrentLevelAttributes. indent=\"$indent\", parent=\"$parent\", parent_begin=$parent_begin, parent_end=$parent_end\n";
   my @name=();
   my @begin=();
   my @end=();
return (\@name,\@begin,\@end) if $parent_begin == $parent_end;

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
sub addPathPrefix{
my ( $prefix, $a )=@_;
return "$prefix:$a";
}
#================================================================
sub getAllAssignmentFullPaths{
my ($apath, $aname, $abegin, $aend)=@_;
print "DEBUG: Entering getAllAssignmentFullPaths. apath=\"$apath\", aname=\"$aname\", abegin=\"$abegin\", aend=\"aend\"\n";
  my @aline=();
  for ( my $i=$abegin; $i <= $aend; $i++){
      push @aline, $line[$i];
      last if $line[$i] =~ /\/?>/;
  }
  $aline[0] =~ s/^ *<$aname //;
  $aline[$#aline] =~ s/ *\/?>//;

  my @paths=();
  foreach (@aline){
     my @assignment = m/\w+=".*?"/g;
     push @paths, grep($_=addPathPrefix($apath,$_),@assignment);
  }
foreach (@paths){
print "DEBUG: Leaving getAllAssignmentFullPaths. FullPath=\"$_\"\n";
}
return @paths;
}
