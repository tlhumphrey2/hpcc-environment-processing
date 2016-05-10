#!/usr/bin/perl
=pod
perl parseENV.pl -s node000115^10.0.0.115^node000243^10.0.0.243^node000171^10.0.0.171 20160420-environment.xml|less
perl parseENV.pl -s node000115^10.0.0.115^node000066^10.0.0.66^node000221^10.0.0.221 20160421-newly_created_environment.xml|less
perl parseENV.pl 20160421-newly_created_environment.xml|less
perl parseENV.pl -s "node000115!10.0.0.115" 20160420-environment.xml|less
perl parseENV.pl 20160420-environment.xml|less
perl parseENV.pl 20160420-newly_created_environment.xml|less
perl parseENV.pl 52.33.221.178-environment.xml|less
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

$_=`cat $infile`;
print "DEBUG: Size of file is ",length($_),"\n";

$one_level='.';

local @line = split(/\n/, $_);
($name, $begin, $end)=getAllCurrentLevelAttributes('', '', 0, $#line);
processENV('', $name, $begin, $end);
#================================================================
sub processENV{
my ( $indent, $parent, $parent_begin, $parent_end )=@_;
print "DEBUG: Entering processENV. parent=\"$parent\", parent_begin=$parent_begin, parent_end=$parent_end, line\[parent_begin]=\"$line[$parent_begin]\"\n";

  ($name, $begin, $end)=getAllCurrentLevelAttributes($indent, $parent, $parent_begin, $parent_end);
print "DEBUG: In processENV. parent=\"$parent\", Number of Attributes is ",scalar(@name),"\n";
  for( my $i=0; $i < scalar(@$name); $i++){
    my $name = $name->[$i];
    my $begin = $begin->[$i];
    my $end = $end->[$i];
    print "$indent$name\n";
print "DEBUG: In processENV. For LOOP. name=\"$name\", begin=\"$begin\", end=\"$end\"\n";
    if ( $line[$end] =~ /\<\/$name>/ ){
       my $child_begin=$begin+1;
       my $child_end=$end-1;
print "DEBUG: In processENV. Just before call to processENV. \"$name\" has children. child_begin=\"$child_begin\", child_end=\"$child_end\"\n";
       my $parent=$name;
       processENV("$indent ", $parent, $begin, $end);
print "DEBUG: In processENV. Return from processENV. parent=\"$parent\", parent_begin=$parent_begin, parent_end=$parent_end\n";
    }
  }
}
#================================================================
sub getAllCurrentLevelAttributes{
my ( $indent, $parent, $parent_begin, $parent_end)=@_;
print "DEBUG: Entering getAllCurrentLevelAttributes. indent=\"$indent\", parent=\"$parent\", parent_begin=$parent_begin, parent_end=$parent_end\n";
   my (@name, @begin, @end);
   my $first=1;
   for ($i=$parent_begin; $i <= $parent_end; $i++){
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

=pod
#----------------------------------------------- old code -----------------------------------------------
# Get top level
($next0,$env)=getAttributes($_);
@next0=@$next0;
@env=grep(! /^\s*$/s, @$env);
die "FATAL: The number of Environment attributes was NOT 1.\n" if scalar(@env) != 1;

$env = $env[0];
#: Found 1 Environment attribute.\n\n";

# Get children of Environment.
($env_children_names,$env_children) = getAttributes($env);
@env_children=@$env_children;
@env_children_names=@$env_children_names;

#Print top attribute
print "$next0->[0]\n";
processChildren($env_children,$one_level);

#============================================================
sub processChildren{
my ( $attribute, $indent )=@_;
  foreach my $xml (@$attribute){
     # Does this attribute start with an attribute name?
     my $attr_name='';
     if ( $xml =~ /^\s*\<(\w+)\b/ ){
        $attr_name=$1;
        
	# If attribute ends with a attribute name end tag (instead of just '/>'.
        if ( $xml =~ /\<\/$attr_name>\s*$/s ){
	  my $search_status='';
	  my $head='';
	  if ( $search !~ /^\s*$/ ){
	    # Get head of attribute
	    $head = ( $xml =~ /(\<$attr_name [^><]+?>)/s )? $1 : '' ;
	    if ( $head !~ /^\s*$/ ){
	      #print "DEBUG: head=\"$head\"\n";
	      $search_status=doSearch($search,$head);
	    }
	  }
	  #: Attr after HTTPS. xml=\"$xml\"\n" if ($attr_name eq 'Instance') && ($head !~ /^\s*$/);
	  #print "DEBUG: Attr after HTTPS. xml=\"$xml\"\n" if ($attr_name eq 'Instance');
          print "$indent$attr_name$search_status\n";
          my ($children_names, $children);
          ($children_names,$children) = getAttributes($xml);
          processChildren($children,"$indent$one_level");
        }
	# This attribute is one without any children
	else{
	  # Is there a search?
	  my $search_status='';
	  if ( $search !~ /^\s*$/ ){
	     $search_status=doSearch($search,$xml);
	  }
          print "$indent$attr_name$search_status\n";
	}
     }
     else{   
        print "ERROR: Didn't find name. First few characters are \"",substr($xml,0,20),"\"\n";
     }

     sub doSearch{
     my ( $search, $xml )=@_;
      local $_=$xml;
      my @search_result=();
      foreach my $s (@search){
         if ( /\n(.*?$s.*?)(?=\n|\s*\/>|\s*>)/ ){
	    my $r=$1;
	    $r =~ s/^\s+//;
	    push @search_result, $r;
	 }
      }
      return (scalar(@search_result)>0)? '	SR:'.join("; ",@search_result) : '' ;
     }

     local $prev_attr_name=$attr_name;
  }
}
#============================================================
sub getAttributes{
my ( $xml )=@_;
local $_=$xml;
  # Remove enveloping attribute name
  if ( s/^\s*<(\w+)[^<]*>//s ){
     my $name0=$1;
     s/<\/$name0>//s;
  }

  my @x=();
  my @name=();
  while ( s/(<(\w+)[^<]*>.+?<\/\2>|<(\w+) [^<]+?\/>)//s ){
     push @x, $1;
     push @name, "$2$3";
  }
  return (\@name,\@x);
}
#--------------------------------------------END old code -----------------------------------------------
=cut
