#!/usr/bin/perl
# Copyright 2012, University of Freiburg,
# Author: Niklas <mail@niklas-meinzer.de>.
# Filename: osmStripper.pl

use strict;
use warnings;

my $inputFileName = shift;

my $outputFileName = shift;

# this hash holds all the "known" highways
# i.e the highways we have speeds for
my %knownWays = ("residential" => 1,
                 "motorway" => 1,
                 "trunk" => 1,
                 "primary" => 1,
                 "secondary" => 1,
                 "tertiary" => 1,
                 "motorway_link" => 1,
                 "trunk_link" => 1,
                 "primary_link" => 1,
                 "secondary_link" => 1,
                 "road" => 1,
                 "unclassified" => 1,
                 "unsurfaced" => 1,
                 "living_street" => 1,
                 "service" => 1);

# check if filenames are given
if(!defined $inputFileName || !defined $outputFileName)
{
  die("Usage: osmStripper <inputFile> <outputFile>\n");
}

# use grep to find all nodes that are used in a way in order to
# remove unused ones
#my $grep_out = system("grep -oP '<nd ref=\"\\d+\"' $inputFileName");
my $grep_out = `grep -oP '<nd ref="\\d+"' $inputFileName`;

my %used_nodes;

foreach(split(/\n/, $grep_out)){
  if($_ =~ m/<nd ref="(\d+)"/) {
    $used_nodes{int($1)} = 1;
  }
}


binmode(STDOUT, ":utf8");

my $input;
my $output;
open($input, $inputFileName);
open($output, ">$outputFileName");

my $skipped_nodes = 0;

print $output "<?xml version='1.0' encoding='UTF-8'?>\n<osm version=\"0.6\" generator=\"pbf2osm\">\n";

while(my $line = <$input>)
{
  # check if $line is a node line
  if($line =~ /<node/)
  {
    # split the lines by spaces
    my @splitted = split / /, $line;
    # will hold the lat, lon and id part
    my %nodeParts;
    my $node_id;
    foreach my $part (@splitted)
    {
      # add id part
      if($part =~ /^id/)
      {
        $nodeParts{id} = $part;
        # parse the actual id as int
        if($part =~ m/id="(\d+)"/) {
          $node_id = int($1);
        } else {
          die ("Could not extract id!");
        }
        next;
      }
      # add lat part
      if($part =~ /^lat/)
      {
        $nodeParts{lat} = $part;
        next;
      }
      #add lon part
      if($part =~ /^lon/)
      {
        $nodeParts{lon} = $part;
        next;
      }
    }
    my $outputLine = "\t<node " . $nodeParts{id} . " " . $nodeParts{lat} .
        " " . $nodeParts{lon} . "/>\n";
    # print the sanitized node line
    if(exists $used_nodes{int($node_id)}) {
      print $output $outputLine;

    } else {
      $skipped_nodes += 1;
    }
    next;
  }

  # check if $line is the start of a way entry
  if($line =~ /<way /)
  {
    # valid is false by default and set true if a known highway tag is found
    my $valid = 0;
    my $outputWay = "\t<way >\n";
    while(my $otherLine = <$input>)
    {
      if($otherLine =~ /<nd/)
      {
        $outputWay .= $otherLine;
        next;
      }
      if($otherLine =~ /<tag/)
      {
        next unless $otherLine =~ /highway/;
        my @splitted = split / /, $otherLine;
        foreach my $part (@splitted)
        {
          next unless $part =~ /v=/;
          my @value = split /"/, $part;
          if(defined $knownWays{$value[1]})
          {
            $outputWay .= $otherLine;
            $valid = 1;
          }
        }
      }
      if($otherLine =~ /<\/way>/)
      {
        $outputWay .= "\t</way>\n";
        last;
      }
    }
    print $output $outputWay if($valid);
  }

}

print $output "</osm>";
close $input;
close $output;

print "Done!\n";
print "Included " . scalar(keys(%used_nodes)) . " nodes\n";
print "Skipped $skipped_nodes nodes.\n";
