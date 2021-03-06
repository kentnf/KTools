#!/usr/bin/perl

=head
 pathwayTool.pl -- tools for pathway analysis

 author: Yi Zheng
 2014-11-20 convert this script to pathwayTool.pl 
 2014-06-20 fix error in p value calculate
 2014-04-09 init
=cut

use strict;
use warnings;
use IO::File;
use Getopt::Std;
use FindBin;

my %options;
getopts('a:b:c:d:e:f:g:i:j:k:l:m:n:o:p:q:r:s:t:u:v:w:x:y:z:h', \%options);
unless (defined $options{'t'} ) { usage(); }

if	($options{'t'} eq 'prepare')	{ pwy_prepare(\%options, \@ARGV); }	# prepare files for pathway tools
elsif	($options{'t'} eq 'database')	{ pwy_database(@ARGV); }	# convert pathway tools output to tables (for downstrean analysis and MetGenMAP)
elsif	($options{'t'} eq 'table')	{ pwy_table(@ARGV); }	# convert pathwy data file into tab delimit table 
elsif	($options{'t'} eq 'filter')	{ pwy_filter(@ARGV); }	# filter pathway tables 
elsif	($options{'t'} eq 'unique')	{ pwy_uniq(@ARGV); }	# 
elsif	($options{'t'} eq 'enrich')	{ pwy_enrich(@ARGV); }	# enrichment analysis
else	{ usage(); }

=head2
 pwy_prepare: prepare files for pathway tools
=cut
sub pwy_prepare
{
	my ($options, $files) = @_;

	my $usage = qq'
USAGE: $0 -t prepare [options] input_AHRD > output 

	-c	UniProt_GO (prepared by dbtool -- uniprot2go)

* the output file should be end with .pf

';
	print $usage and exit unless defined $$files[0];
	my $input_file = $$files[0];
	die "[ERR]file not exist\n" unless -s $$files[0];

	# check uniprot EC database
	my $tr_ec = $FindBin::RealBin."/database/uniprot_trembl_plants.dat.id.txt.gz";
	my $sp_ec = $FindBin::RealBin."/database/uniprot_sprot_plants.dat.id.txt.gz";

	# load uniprot ID to hash, 
	my %pre_load_id; # key: uniprot id(AHRD)
	my $fha = IO::File->new($input_file) || die $!;
	while(<$fha>) {
		chomp;
		next if $_ =~ m/^#/;
		my @a = split(/\t/);
		next if @a < 4;
		my $uniprot_id = $a[1];
		my $uid = $uniprot_id;
		$uid =~ s/^tr\|//;
		$uid =~ s/^sp\|//;

		$pre_load_id{$uid} = 1;
		$pre_load_id{$uniprot_id} = 1;
	}
	$fha->close;
	print scalar(keys(%pre_load_id))." uniprot ID loaded\n";

	# load plant EC number to hash 
	# key: uniprot_id, value: EC number
	my %uniprot_ec;
	foreach my $f (($tr_ec, $sp_ec)) {
		die "[ERR]file not exist $f\n" unless -s $f;
		my $fh;
		if ($f =~ m/\.gz$/) {
			open($fh, '-|', "gzip -cd $f") || die $!;
		} else {
			open($fh, $f) || die $!;
		}
		while(<$fh>) {
			chomp;
			my @a = split(/\t/, $_);
			next if @a == 1;
			if (defined $pre_load_id{$a[0]}) {
				$uniprot_ec{$a[0]} = $a[1];
			}
		}
		close($fh);
	}
	print scalar(keys(%uniprot_ec))." uniprot EC loaded\n";

	# load plant GO ID to hash
	# key: uniprot_id, value: GO
	# * notice, the uniprot id does not have database name
	my %uniprot_go;
	if (defined $$options{'c'}) {
		die "[ERR]file not exist\n" unless -s $$options{'c'};
		my $fh;
		if ($$options{'c'} =~ m/\.gz$/) {
			open($fh, '-|', "gzip -cd $$options{'c'}") || die $!;
		} else {
			open($fh, $$options{'c'}) || die $!;
		}
		while(<$fh>) {
			chomp;
			my @a = split(/\t/, $_, 2);
			if (defined $pre_load_id{$a[0]}) {
				$uniprot_go{$a[0]} = $a[1];
			}
		}
		close($fh);
	}
	print scalar(keys(%uniprot_go))." uniprot GO loaded\n";

	# set file path
	my $organism_dat    = 'organism-params.dat';
	my $genetic_element = 'genetic-elements.dat';
	my $gene_annotation = 'gene-annotation.pf';

# ====================================
# Please change below content manually
# ====================================
	# init organism.dat
	my $organism_dat_content = qq';;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; generated automatically by kentnf pathway script
;; attribute format: ID [tab] value
;; Valid attributes:
;; ID (unique, 2-10 characters, no spaces) requied
;; STORAGE (File, MySQL, Oracle) [defaults File]
;; NAME (genus species) required
;; ABBREV-NAME
;; SUBSPECIES
;; STRAIN
;; PRIVATE? (either T or NIL) [defaults: NIL]
;; DOWNLOAD-TIMESTAMP
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

ID	ROSE
STORAGE	FILE
NAME	Rosa hybrid cultivar
ABBREV-NAME	R. hybrid
AUTHOR	Yi Zheng:BTI
HOMEPAGE	http://bioinfo.bti.cornell.edu
EMAIL	yz357\@cornell.edu
DBNAME	RoseCyc
COPYRIGHT	<a href=http://bioinfo.bti.cornell.edu>Fei Lab</a>
NCBI-TAXON-ID	128735
';

	# create_genetic_elements
	my $genetic_element_content = qq'ID	TEST-CHROM-1
NAME	PseudoChromosome
TYPE	:CHRSM
CIRCULAR?	N
ANNOT-FILE	gene-annotation.pf
//
';
# ====================================
# end of content need manually change
# ====================================

	# prepare gene annotation file
	my $gene_annotation_content = '';

	my ($id, $uniprot_id, $desc, $num); $num = 0;
        my $fh = IO::File->new($input_file) || die $!;
        while(<$fh>)
        {
                chomp;
                next if $_ =~ m/^#/;
                my @a = split(/\t/);
                next if @a < 4;
                $id = $a[0];
		$uniprot_id = $a[1];
                $desc = $a[3];
		my $ec = '';
		my $go = '';
		if ( defined $uniprot_ec{$uniprot_id} ) {
			my @ecs = split(/;/, $uniprot_ec{$uniprot_id});
			foreach my $ec_id ( @ecs ) {
				$ec.="EC\t$ec_id\n";	# should be update
			}
		}
		
		my $uid = $uniprot_id;
		$uid =~ s/tr\|//; $uid =~ s/sp\|//;
		if ( defined $uniprot_go{$uid}) {
			my @gos = split(/; /, $uniprot_go{$uid});
			foreach my $go_id (@gos) {
				$go.="DBLINK\t$go_id\n";	# should be update
			}
		}
		
		next if $desc eq 'No hit';
                $gene_annotation_content.="ID\t$id\nNAME\t$id\nPRODUCT-TYPE\tP\nFUNCTION\t$desc\n";
		$gene_annotation_content.=$ec if $ec;
		$gene_annotation_content.=$go if $go;
		$gene_annotation_content.="//\n\n";
		$num++;
	}
	$fh->close;

	# save file to folder
	mkdir("param-dir") unless -s "param-dir";
	save_file($organism_dat_content,    "param-dir/$organism_dat");
	save_file($genetic_element_content, "param-dir/$genetic_element");
	save_file($gene_annotation_content, "param-dir/$gene_annotation");

	print "./pathway-tools -patho param-dir/\n";

}

sub save_file 
{
	my ($content, $file) = @_;
	open(FH, ">$file") || die $!;
	print FH $content;
	close(FH);
} 

=head2
 pwy_table: convert pathway tools output to tables (for downstrean analysis and MetGenMAP)
=cut
sub pwy_table
{
	my ($pwy_col, $ahrd) = @_;

	my $usage = qq'
USAGE: $0 -t table pathways.col AHRD > gene_pathway_table.txt

* format of gene pathway table
GeneID [TAB] AHRD [TAB] PWY-ID [TAB] PWY-Name

';
	print $usage and exit unless (defined $pwy_col && defined $ahrd);
	foreach my $f (($pwy_col, $ahrd)) { die "[ERR]file not exist $f\n" unless -s $f; }

	# load ahrd to hash
	my %ahrd;
	my $ah = IO::File->new($ahrd) || die $!;
	while(<$ah>)
	{
		chomp;
		my @a = split(/\t/, $_);
		next if scalar @a < 4;
		$ahrd{$a[0]} = $a[3];
	}
	$ah->close;

	# parse pathways.col 
	my @t;	# array for title
	my $fh = IO::File->new($pwy_col) || die $!;
	while(<$fh>) {
		chomp;
		next if $_ =~ m/^#/;
		@t = split(/\t/, $_);
		die "[ERR]UID title\n" unless $t[0] eq 'UNIQUE-ID';
		die "[ERR]Name title\n"  unless $t[1] eq 'NAME';
		last;
	}

	while(<$fh>)
	{
		chomp;
		next if $_ =~ m/^#/;
		my @a = split(/\t/, $_);
		my ($pwy_id, $pwy_name) = ($a[0], $a[1]);
		for(my $i=2; $i<@a; $i++) {
			next if $t[$i] ne "GENE-NAME";
			next unless $a[$i] =~ m/\w/;
			die "[ERR]Undef AHRD $a[$i]\n" unless defined $ahrd{$a[$i]};
			print "$a[$i]\t$ahrd{$a[$i]}\t$pwy_id\t$pwy_name\n";
		}
	}
	$fh->close;
}

=head2
 pwy_filter: filter the pathway result for removing none-plant pathways
=cut
sub pwy_filter
{
	my $pathway_file = shift;

        my $usage = qq'
USAGE: $0 -t filter pathway_file

* output files
1) input_file.kept : the kept pathway for next analysis
2) input_file.remove : the removed pathway

';
	print $usage and exit unless defined $pathway_file;
	die "[ERR]file not exist\n" unless -s $pathway_file;

	my $pathway_kept   = $pathway_file.".kept";
	my $pathway_remove = $pathway_file.".remove";

	open(OUT1, ">".$pathway_kept) || die $!;
	open(OUT2, ">".$pathway_remove) || die $!;
	open(FH, $pathway_file) || die $!;
	while(<FH>)
	{
		chomp;
		next if $_ =~ m/^#/;
		my @a = split(/\t/, $_);
		if ($a[3] =~ m/\s+\((.+?)\)$/)
		{
			my $cc = $1;
			$cc =~ s/cytochrome c\) \(//;
			if($cc eq 'yeast' || $cc eq 'prokaryotic' || $cc eq 'obligate autotrophs' || $cc eq 'Gram-negative bacteria' ||
			   $cc eq 'Gram-positive bacteria' || $cc eq 'mammals' || $cc eq 'metazoan' || $cc eq 'animals')
			{
				print OUT2 $_."\n";
			}
			else
			{
				print OUT1 $_."\n";
			}
		}
		else
		{
			print OUT1 $_."\n";
		}
	}
	close(FH);
	close(OUT1);
	close(OUT2);
}


=head2
 pwy_uniq: uniq the pathway report file
=cut
sub pwy_uniq
{
	my ($pathway_file) = shift;
	
	my $usage = qq'
USAGE: $0 -t unique pathway_file > uniq_pathway_file

';

	my %p;
	my $fh = IO::File->new($pathway_file) || die $!;
	while(<$fh>)
	{
        	chomp;
	        # MIN031488       Zeaxanthin epoxidase, chloroplastic     PWY-5945        zeaxanthin, antheraxanthin and violaxanthin interconversion
	        my @a = split(/\t/, $_);

	        if (defined $p{$a[2]}{'num'} ) {
	                $p{$a[2]}{'num'}++;
	        } else {
	                $p{$a[2]}{'num'} = 1;
	        }

	        $p{$a[2]}{'desc'} = $a[3];
	}
	$fh->close;

	foreach my $id (sort keys %p) {
        	print $id."\t".$p{$id}{'num'}."\t".$p{$id}{'desc'}."\n";
	}
}

=head2 
 pwy_enrich: pathway enrichment analysis
=cut
sub pwy_enrich
{
	my ($gene_list,$pathway_file) = @_;

	my $usage = qq'
USAGE: $0 -t enrich input_gene_list pathway_file

* the input gene list should be changed gene in DE analysis
* the pathway file should be output of pathways tools

';
	print $usage and exit unless (defined $gene_list && defined $pathway_file);
	foreach my $f (($gene_list,$pathway_file)) { die "[ERR]file not exist\n" unless -s $f; }

	# load gene list (changed gene) to hash
	my %changed_gene;
	my $fh1 = IO::File->new($gene_list) || die $!;
	while(<$fh1>)
	{
		chomp;
		$changed_gene{$_} = 1;
	}
	$fh1->close;

	# load pathway to hash
	# key: pwy_id
	# value: pwy_name
	#
	# key: pwy_id
	# value: gene1 \t gene2 \t ... \t geneN
	# 
	# check pwy id and name uniq at same time
	my %pwy_name;
	my %pwy_gene;
	my %all_pwy_gene;
	my %all_pwy_changed_gene;

	my $fh2 = IO::File->new($pathway_file) || die $!;
	while(<$fh2>)
	{
		chomp;
		next if $_ =~ m/^#/;
		#gene_ID        gene_description        pathway_ID      pathway_name
		my @a = split(/\t/, $_);
		die "Error in line $_\n" unless scalar @a == 4;
		my ($gid, $g_desc, $pid, $p_name) = @a;

		# check pwy id and pwy name
		if (defined $pwy_name{$pid} )
		{
			die "Error in pwy $pid\n" if $p_name ne $pwy_name{$pid};
		}
		else
		{
			$pwy_name{$pid} = $p_name;
		}

		if (defined $pwy_gene{$pid})
		{
			$pwy_gene{$pid}.= "\t".$gid;
		}
		else
		{
			$pwy_gene{$pid} = $gid;
		}

		$all_pwy_gene{$a[0]} = 1;

		if ( defined $changed_gene{$a[0]} )
		{
			$all_pwy_changed_gene{$a[0]} = 1;
		}

	}
	$fh2->close;

	my $N = scalar(keys %all_pwy_gene);		# N: gene in all pathways
	my $n = scalar(keys %all_pwy_changed_gene);	# n: changed gene in pathways

	# uniq the gene in each pwy, then get pvalue of changed pathways
	my %uniq_gene;
	my @uniq_gene;
	my $temp_file = "temp_output";
	my $out1 = IO::File->new(">".$temp_file) || die $!;

	foreach my $pid (sort keys %pwy_gene)
	{
		%uniq_gene = ();
		my @gene = split(/\t/, $pwy_gene{$pid});

		foreach my $gid (@gene) { $uniq_gene{$gid} = 1; }
		@uniq_gene = sort keys %uniq_gene;

		my $M = scalar(@uniq_gene);		# M: gene in particular pathways
		my $x = 0;				# x: changed gene in particular pathways
		foreach my $gid (@uniq_gene) {
			if ( defined $changed_gene{$gid} ) {
				$x++;
			}
		}
	
		my $p_name = $pwy_name{$pid};

		# compute pvalue
		#################################################################################
		#  input format
		#  hypergeometric(N, n, M, x);
		#  N: gene in all pathways
		#  n: changed gene in pathways
		#  M: gene in particular pathways
		#  x: changed gene in particular pathways
		#
		#  check this link for confirmation:
		#  http://www.geneprof.org/GeneProf/tools/hypergeometric.jsp
		################################################################################

		if ($x > 0) {
			# the order should be N M n x
			# my $pvalue = hypergeometric($N, $n, $M, $x);
			my $pvalue = hypergeometric($N, $M, $n, $x);
			my $background = "$M out of $N genes";
			my $cluster = "$x out of $n genes";
			print $out1 "$pid\t$p_name\t$cluster\t$background\t$pvalue\n";
		}
	}
	$out1->close;

	# adjust p value to q value
	my $output_dat = $gene_list."_changed_pwy.table.txt";

	my $R_CODE =<< "END";
library(qvalue)
data<-read.delim(file="$temp_file", header=FALSE)
p<-data[,5]
qobj<-qvalue(p)
alldata<-cbind(data,qobj\$qvalue)
write.table(file="$output_dat", sep="\\t", alldata);
END

	#print $R_CODE; exit;
	open R,"|/usr/bin/R --vanilla --slave" or die $!;
	print R $R_CODE;
	close R;

	#unlink($temp_file);


	# better to parse the output file format
}

#####################
###  Subroutines  ###
#####################

sub hypergeometric {
    my $n = $_[0]; # N Total number of genes in all the pathways
    my $np = $_[1];# M Total number of genes in a particular pathway
    my $k = $_[2]; # n Total number of changed genes (in the input list) from all the pathways
    my $r = $_[3]; # x total number of changed genes (in the input list) from the particular pathway
    my $nq;
    my $top;
    
    $nq = $n - $np;

    my $log_n_choose_k = lNchooseK( $n, $k );

    $top = $k;
    if ( $np < $k ) {
        $top = $np;
    }

    my $lfoo = lNchooseK($np, $top) + lNchooseK($nq, $k-$top);
    my $sum = 0;

    for (my $i = $top; $i >= $r; $i-- ) {
        $sum = $sum + exp($lfoo - $log_n_choose_k);

        if ( $i > $r) {
            $lfoo = $lfoo + log($i / ($np-$i+1)) +  log( ($nq - $k + $i) / ($k-$i+1)  )  ;
        }
    }
    return $sum;
}

sub lNchooseK {
    my $n = $_[0];
    my $k = $_[1];
    my $answer = 0;

    if( $k > ($n-$k) ){
        $k = ($n-$k);
    }

    for(my $i=$n; $i>($n-$k); $i-- ) {
        $answer = $answer + log($i);
    }

    $answer = $answer - lFactorial($k);
    return $answer;
}

sub lFactorial {
    my $returnValue = 0;
    my $number = $_[0];
    for(my $i = 2; $i <= $number; $i++) {
        $returnValue = $returnValue + log($i);
    }
    return $returnValue;
}


=head2
 usage: show usage information
=cut
sub usage
{
	my $usage = qq'
USAGE $0 -t [tool]

	prepare	prepare AHRD files for pathway tools
	talbe	convert pathway tools output to tables (for downstrean analysis and MetGenMAP)
	filter	filter the pathway result to remove non-plant pathways
	unique	unique the pathway identified result
	enrich	enrichemnt analysis for gene list

Pipelines:
	\$ pathwayTool.pl -t prepare AHRD files for pathway tools
	\$ pathwayTool.pl -t convert pathway tools output to tables (for downstrean analysis and MetGenMAP)
	\$ pathwayTool.pl -t filter input_pathway(the input file is generate by ptools)
	\$ pathwayTool.pl -t unique input_pathway.kept
	\$ pathwayTool.pl -t enrich gene_list input_pathway.kept

';

	print $usage;
	exit;
}

