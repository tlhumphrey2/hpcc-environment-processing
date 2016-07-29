#!/usr/bin/perl
=pod
perl NestedFolders2ENV.pl 20160509-1-environment.xml|less
perl NestedFolders2ENV.pl 20160420-environment.xml|less
perl NestedFolders2ENV.pl 20160420-newly_created_environment.xml|less
perl NestedFolders2ENV.pl 52.33.221.178-environment.xml|less
=cut

#================== Get Arguments ================================
require "newgetopt.pl";
if ( ! &NGetOpt(
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


$outfile = shift @ARGV;
$basename=( $outfile=~/^(.+)\.xml$/ )? $1 : $outfile ;

@line = ();
push @line, '<?xml version="1.0" encoding="UTF-8"?>';
push @line, '<!-- Generated NestedFolders2ENV.pl -->';


my $name=getDirectoryContents($basename); 
print "DEBUG: After calling DirectoryContents. Number in \@name=",scalar(@$name),". First name is \"$name->[0]\".\n";

processENV('', $name->[0], "$basename/$name->[0]");

die "ERROR: Too few lines in \@line, i.e. ",scalar(@line),"\n" if scalar(@line) < 10;

$outfile = ( $outfile =~ /^(.+\/)([^\/]+)$/ )? "${1}new_$2" : "new_$outfile";
print STDERR "Outputting $outfile\n";
open(OUT,">$outfile") || die "Can't open for output \"$outfile\"\n";
print OUT join("\n",@line),"\n";
close(OUT);

#================================================================
sub processENV{
my ( $indent, $parent, $path )=@_;
  my $HasChildren=0;
print "DEBUG: Entering processENV. parent=\"$parent\", path=\"$path\"\n";
  my $name=getDirectoryContents($path);
print "DEBUG: In processENV. After call to getDirectoryContents. parent=\"$parent\". Size of \@name=",scalar(@$name),", \@name=",join(",",@$name),"\n";

  # If there are children then make $parent directory
  if ( scalar(@$name) > 0 ){
     $HasChildren=1;
     # Does parent header. If so then store it.
     if ( $name->[0] eq 'ahead' ){
	my $head=`cat $path/$name->[0]`;
print "DEBUG: In processENV. CHILDREN FOUND for \"$parent\" AND HEAD=\"$name->[0]\"\n";
	$head=~ s/\n+$//;
	push @line, $head;
	shift @$name;
     }
     else{
print "DEBUG: In processENV. CHILDREN FOUND for \"$parent\" AND NO HEAD\n";
        my $name0 = ($parent =~ /^(\w+)#\d+$/)? $1 : $parent ;
	push @line, "$indent<$name0>";
     }
  }
  else{
print "DEBUG: In processENV. NO CHILDREN FOUND for \"$indent\<$name0\>\"\n";
     my $content=`cat $path`;
     $content=~ s/\n+$//;
     push @line, $content;
  }

  for( my $i=0; $i < scalar(@$name); $i++){
    my $name = $name->[$i];
    my $begin = $begin->[$i];
    my $end = $end->[$i];
    $FirstAttribute=0;

    my $name0 = ($name =~ /^(\w+)#\d+$/)? $1 : $name ;
    print "$indent$name0\n";

    $cbegin = $begin+1;
    $cend=($line[$end] =~ /^$indent\<\/$name>/)? $end-1 : $end ;
    processENV("$indent ", $name, "$path/$name" );
  }

  if ( $HasChildren ){
      my $name0 = ($parent =~ /^(\w+)#\d+$/)? $1 : $parent ;
      push @line, "$indent</$name0>";
  }
}
#================================================================
sub getDirectoryContents{
my ( $dir )=@_;
print "DEBUG: Entering getDirectoryContents. dir=\"$dir\"\n";
  my @contents=();
  return \@content if -f $dir;

  if ( opendir(DIR,$dir) ){
      my @dir_entry = readdir(DIR);
      closedir(DIR);
      @contents=grep( ! /^\./,@dir_entry); # Get the names of ONLY the metadata xml files
      my $nFiles=scalar(@contents);
print "DEBUG: In getDirectoryContents. There are $nFiles files.\n";
      die "ERROR: No files in this directory, \"$dir\"\n" if $nFiles==0;
      my ( $head )=grep(/^ahead$/,@contents);
print "DEBUG: In getDirectoryContents. head=\"$head\"\n";
      @contents = grep(!/^ahead$/,@contents);
      if ( $head ne '' ){
      unshift @contents, $head;
print "DEBUG: In getDirectoryContents. FOUND HEAD and placed as first of \@content: \"$contents[0]\"\n";
      }
  }
  else{
     die "In getDirectoryContents. ERROR: Couldn't open directory for \"$dir\"\n";
  }
return \@contents;
}
#================================================================
sub saveHeader{
my ( $attr_name, $path, $begin )=@_;
print "DEBUG: Entering saveHeader. attr_name=\"$attr_name\", path=\"$path\", begin=\"$begin\"\n";
   my (@name, @begin, @end);
   my $first=1;
   my @head=();
   for ($i=$begin; $i < scalar(@line); $i++){
     $head[$i]=~ s/\n+$//;
     if ( $first ){
        $first=0;
	die "FATAL ERROR: In saveHeader. attr_name=\"$attr_name\". Start attribute was NOT found. EXITING.\n" if $line[$i] !~ /^\s*\<$attr_name /;
	push @head, $line[$i];
	last if $line[$i] =~ /(\<$attr_name [^><]+>)/;
     }
     elsif ( $line[$i] =~ /^\s*[^><]+$/ ){
	push @head, $line[$i];
     }
     elsif ( $line[$i] =~ /^\s*[^><]*>\s*$/ ){
	push @head, $line[$i];
	last;
     }
     else{
	die "FATAL ERROR: In saveHeader. attr_name=\"$attr_name\". DID NOT FOUND end of header. line\[$i\]=\"$line[$i]\". EXITING.\n";
     }
   }
   my $head = join("\n",@head);
   saveFile($head,"$path/ahead");
}
#================================================================
sub my_mkdir{
my ( $dir )=@_;
  $dir=UniquePath($dir);
  mkdir $dir if ! -e $dir;
print "DEBUG: In my_mkdir. dir=\"$dir\"\n";
return $dir;
}
#================================================================
sub my_chdir{
my ( $dir )=@_;
  $dir=UniquePath($dir);
  chdir($dir) or die "Could NOT cd into directory: \"$dir\". $!";
print "DEBUG: In my_chdir. dir=\"$dir\"\n";
return $dir;
}
#================================================================
sub UniquePath{
my ( $path )=@_;
print "DEBUG: Entering UniquePath. path=\"$path\".\n";
print "DEBUG: In UniquePath. Keys to \%PathExists are (",join("\n   DEBUG: In UniquePath. Keys to \%PathExists are ",keys %PathExists),").\n";
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
print "DEBUG: Entering modifyName. path=\"$path\".\n";
     while ( $PathExists{$path} ){
       my $n = ( $path =~ s/#(\d+)$// )? $1 : 0 ;
       $path = sprintf "%s#%03d", $path,$n+1;
print "DEBUG: In modifyName. After mod. path=\"$path\".\n";
     }
     $PathExists{$path}=1;
print "DEBUG: Leaving modifyName. path=\"$path\".\n";
 return $path;
}
#================================================================
sub saveFile{
my ( $xml, $FileFullPath )=@_;
print "DEBUG: In saveFile. FileFullPath=\"$FileFullPath\".\n";
   $FileFullPath=UniquePath($FileFullPath) ;
print "DEBUG: In saveFile. After UniquePath FileFullPath=\"$FileFullPath\".\n";
   open(OUT,">$FileFullPath") || die "Can't open for output \"$FileFullPath\"\n";
   print OUT $xml;
   close(OUT);
}

