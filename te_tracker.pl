#!/usr/bin/env perl

##
## TE tracker
## reubwn 2018
##

use strict;
use warnings;
use Getopt::Long;
use Sort::Naturally;
use Data::Dumper;

my $usage = "
SYNOPSIS

OPTIONS
  -1|--bed1        [FILE]   : BED file for species 1
  -2|--bed2        [FILE]   : BED file for species 2
  -r|--orthofinder [FILE]   : OrthoFinder 'OrthoGroups.txt' file
  -o|--out         [STRING] : Output filename
  -h|--help                 : this message

OUTPUTS

\n";

my ($bed1file, $bed2file, $orthofinderfile, $outfile, $help, $debug);

GetOptions (
  '1|bed1=s' => \$bed1file,
  '2|bed2=s' => \$bed2file,
  'r|orthofinder=s' => \$orthofinderfile,
  'o|outfile:s' => \$outfile,
  'h|help' => \$help,
  'd|debug' => \$debug
);

die $usage if $help;
die $usage unless ($bed1file && $bed2file && $orthofinderfile);

## parse OrthoGroups.txt file:
my (%orthogroups_hash, %membership_hash);
open (my $OG, $orthofinderfile) or die $!;
while (<$OG>) {
  chomp;
  my @a = split (": ", $_);
  my @b = split (/\s+/, $a[1]);
  $orthogroups_hash{$a[0]} = \@b; ##key= OG#; val= @[ geneids ]
  foreach (@b) {
    ## each gene has its OG#
    $membership_hash{$_} = $a[0]; ##key= geneid; val= OG#
  }
}
close $OG;
print STDERR "[INFO] Number of OGs in $orthofinderfile: ".(keys %orthogroups_hash)."\n";
print STDERR "[INFO] Number of genes in $orthofinderfile: ".(keys %membership_hash)."\n";

## parse BED2 file:
my (%bed1, %bed2, %bed2_positional, %bed2_membership);
open (my $BED2, $bed2file) or die $!;
while (<$BED2>) {
  chomp;
  my @a = split (/\s+/, $_);
  push ( @{$bed2_positional{$a[0]}{starts}}, $a[1] );
  push ( @{$bed2_positional{$a[0]}{ends}}, $a[2] );
  push ( @{$bed2_positional{$a[0]}{feature}}, $a[3] );

  if ($membership_hash{$a[3]}) {
    $bed2{$a[3]} = {
      'chrom' => $a[0],
      'start' => $a[1],
      'end'   => $a[2],
      'OG'    => $membership_hash{$a[3]}
    };
    $bed2_membership{$membership_hash{$a[3]}} = $a[3]; ##key= OG#; val= geneid sp2
  }
}
close $BED2;
print Dumper (\%bed2_positional) if $debug;
print Dumper (\%bed2) if $debug;

## open BED1 file:
open (my $BED1, $bed1file) or die $!;
while (<$BED1>) {
  chomp;
  my @a = split (/\s+/, $_);

  if ($membership_hash{$a[3]}) { ## is gene
    if ($bed2_membership{$membership_hash{$a[3]}}) {
      ## need to essentially align the relevant region from BED2 to the BED1 region, anchored by OG#
      print join ("\t", @a, $membership_hash{$a[3]}, $bed2_membership{$membership_hash{$a[3]}}, "\n");
    } else {
      print join ("\t", @a, $membership_hash{$a[3]}, "-", "\n");
    }
  } else {
    print join ("\t", @a, "-", "-", "\n");
  }

  $bed1{$a[3]} = { 'chrom' => $a[0], 'start' => $a[1], 'end' => $a[2] };

}
close $BED1;
