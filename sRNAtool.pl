#!/usr/bin/perl

=head1
 sRNAtool -- tools for sRNA data preparation
 plan -- add Q20 Function, range function
 clip from 5' and 3' function by the end of this Sept 2014
 insert miRNA identification pipeline, debug, 
 insert sPARTA to it, debug
 insert ta-si analysis to it debug
 by the end of 2014, check if there is any pipeline could be used for improve 24nt sRNA analysis
 write document on reddocs
=cut

use strict;
use warnings;
use IO::File;
use Getopt::Std;

my $version = 0.1;
if (@ARGV < 1) { usage($version);}
my $tool = shift @ARGV;

my %options;
getopts('i:o:p:s:c:fuh', \%options);

if	($tool eq 'convert') { convert(\%options); }
elsif	($tool eq 'lengthd') { lengthd(\%options); }
elsif	($tool eq 'unique' ) { unique(\%options);  }
elsif   ($tool eq 'norm' )   { norm(\%options);    }
elsif   ($tool eq 'normcut') { normcut(\%options); }
elsif   ($tool eq 'combine') { combine(\%options); }
elsif	($tool eq 'chkadp')  { chkadp(\%options);  }
elsif	($tool eq 'rmadp3')  { rmadp3(\%options);  }
elsif   ($tool eq 'rmadp5')  { rmadp5(\%options);  }
elsif	($tool eq 'range')   { range(\%options);   }
else	{ usage($version); } 

#################################################################
# kentnf: subroutine						#
#################################################################
=head2
 rmadp3 -- remove 3p adapter 
=cut
sub rmadp5
{
	my $options = shift;
	
	my $subUsage = qq'
USAGE: $0 rmadp5 [options]
	-i	input file
	-s	adapter sequence
	-l	adapter length
	-d	distance between adater and sRNA 
	-o	output file[default: input_file.ra3]

';
	my ($adp_length, $distance, $outFile);
	$adp_length = 9;
	$distance = 0;

	print $subUsage and exit unless $$options{'i'};
	print $subUsage and exit unless $$options{'s'};
	my $inFile  = $$options{'i'};
	my $adapter = $$options{'s'};
	$outFile = $inFile.".ra3";
	$adp_length = $$options{'l'} if defined $$options{'l'};
	$distance = $$options{'d'} if defined $$options{'d'};
	$outFile = $$options{'o'} if defined $$options{'o'};

	die "[ERR]in file not exist\n" unless -s $inFile;
	die "[ERR]out file exist\n" if -s $outFile;
	die "[ERR]short adapter\n" if ( length ($adapter) < $adp_length );

	#my $subadp = substr($adapter, , );


	my $format;
	my $out = IO::File->new($outFile) || die $!;
	my $fh = IO::File->new($inFile) || die $!;
	while(<$fh>)
	{
		chomp;
		my $id = $_;
		if      ($id =~ m/^>/) { $format = 'fasta'; }
		elsif   ($id =~ m/^@/) { $format = 'fastq'; }
		else    { die "[ERR]seq format $id\n"; }
		my $seq = <$fh>; chomp($seq); $seq = uc($seq);
	
			
	}
	$fh->close;
	$out->close;
}

=head2
 chkadp -- check adapter using k-mer method
=cut
sub chkadp
{
	my $options = shift;
	
	my $subUsage = qq'
USAGE: $0 chkadp [options]
	-i	inuput file

';

	my $min_len = 15;
	my $kmer_len = 9;
	my $read_yeild = 1e+5;

	print $subUsage and exit unless $$options{'i'};
	my $inFile = $$options{'i'};
	die "[ERR]File not exist\n" unless -s $inFile;	

	my %kmer_ct;		# key: kmer; value: count;
	my $kmer_most;		# the most freq kmer
	my $kmer_most_freq = 0; # the count of most freq kmer

	my $seq_ct = 0; my $format;
	my $fh = IO::File->new($inFile) || die $!;
	while(<$fh>)
	{
		chomp;
		my $id = $_;
		if	($id =~ m/^>/) { $format = 'fasta'; }
		elsif	($id =~ m/^@/) { $format = 'fastq'; }
		else 	{ die "[ERR]seq format $id\n"; }
		my $seq = <$fh>; chomp($seq); $seq = uc($seq);
		
		my $k_count = length($seq) - $min_len - $kmer_len + 1;
		for(my $i=0; $i<$k_count; $i++) 
		{
			my $k = substr($seq, $min_len + $i, $kmer_len);
			if ( defined $kmer_ct{$k} ) 
			{
				$kmer_ct{$k}++;
				if ($kmer_ct{$k} > $kmer_most_freq) 
				{
					$kmer_most_freq = $kmer_ct{$k};
					$kmer_most = $k;
				}
			}
			else 
			{
				$kmer_ct{$k} = 1;
			}
		}

		if ($format eq 'fastq') { <$fh>; <$fh>; }
		$seq_ct++;
		last if $seq_ct == $read_yeild;
	}
	$fh->close;

	# process extend kmer most
	my @base = ("A", "T", "C", "G");
	print "#kmer\tcount\n$kmer_most\t$kmer_most_freq\n";
	my $pre_k = $kmer_most;
	for(my $i=0; $i<$min_len; $i++)
	{
		my ($best_kmer, $best_kmer_count);
		$best_kmer_count = 0;
		my $subk = substr($pre_k, 0, $kmer_len-1);
		foreach my $b (@base)
		{
			my $k = $b.$subk;
			if (defined $kmer_ct{$k} && $kmer_ct{$k} > $best_kmer_count) {
				$best_kmer = $k;
				$best_kmer_count = $kmer_ct{$k};
			}
		}
		$pre_k = $best_kmer;
		print "$best_kmer\t$best_kmer_count\n";
	}	
}

=head2
 rmadp -- remove adapter from sRNA sequence
=cut
sub rmadp
{
	my $options = shift;

	my $subUsage = qq'
USAGE: $0 rmadp [options]
        -i      input file 
        -a      adapter sequence
        -l 	length 
        -f      convert table to fasta (default:0) / fasta to table (1)
<not finished>

';
	
}

=head2
 convert -- convert table format (GEO database) to fasta format (default), or fasta format to table format
=cut
sub convert
{
	my $options = shift;

	my $subUsage = qq'
USAGE: $0 convert [options]
	-i	input file 
	-o	output prefix (defaul:sRNAseq)
	-p	prefix of out seqID (for table convert to fasta)
	-f	convert table to fasta (default:0) / fasta to table (1)

';

	print $subUsage and exit unless $$options{'i'}; 
	my $out_prefix = 'sRNAseq';
	$out_prefix = $$options{'o'} if $$options{'o'};


	my ($inFile, $outFile, $format, $prefix);
	$inFile = $$options{'i'};
	$prefix = $inFile; $prefix =~ s/\..*//;
	$prefix = $$options{'p'} if $$options{'p'};
	$format = 0;
	$format = 1 if $$options{'f'};

	my %read; my $num;
	if ($format) {
		$outFile = $out_prefix.".tab";
		die "[ERR]output file $outFile exist\n" if -s $outFile;
		my $out = IO::File->new(">".$outFile) || die $!;
		my $in = IO::File->new($inFile) || die $!;
		while(<$in>)
		{
			chomp;
			my $id = $_;
			my @a = split(/-/, $id);
			die "[ERR]sRNA ID: $id\n" unless @a == 2;
			die "[ERR]sRNA num: $a[1]\n" unless $a[1] > 0;
			my $rd = <$in>; chomp($rd);
			if ( defined $read{$a[0]} ) {
				$read{$rd} = $read{$rd} + $a[1];
				print "[WARN]Repeat Uniq sRNA Read $a[0]\n";
			} else {
				$read{$rd} = $a[1];
			}
		}
		$in->close;

		foreach my $r (sort keys %read)
		{
			print $out $r."\t".$read{$r}."\n";
		}
		$out->close;

	} else {
		$outFile = $out_prefix.".fasta";
		die "[ERR]output file $outFile exist\n" if -s $outFile;
		my $out = IO::File->new(">".$outFile) || die $!;
		my $in = IO::File->new($inFile) || die $!;
		while(<$in>)
		{
			chomp;
			my @a = split(/\t/, $_);
			if ( defined $read{$a[0]} ) {
				$read{$a[0]} = $read{$a[0]} + $a[1];
				print "[WARN]Repeat Uniq sRNA Read $a[0]\n"; 
			} else {
				$read{$a[0]} = $a[1];
			}
		}
		$in->close;

		foreach my $r (sort keys %read)
		{
        		$num++;
			my $count = $read{$r};
			print $out ">".$prefix."A".$num."-".$count."\n$r\n";
		}
		$out->close;
	}
	# foreach my $o (sort keys %$options) { print "$o\t$$options{$o}\n"; }
}

=head2
 unique -- convert the clean sRNA to unique (remove duplication)
=cut
sub unique
{
	my $options = shift;

	my $subUsage = qq'
USAGE: $0 unique [options]
        -i      input file 
        -u      input reads file is sRNA clean (default:0) / uniq (1) format

* convert the clean sRNA to unique
  convert the unique sRNA to clean if -u provide
* output example
  >id000001-10930   # 10930 is the number of sRNA
* support fastq file
* output read is sorted by number, could check the high expressed read

';

	print $subUsage and exit unless $$options{'i'};
	my $input_file = $$options{'i'};
	die "[ERR]cat not find input file $$options{'i'}\n" unless -s $$options{'i'};

	if ($$options{'u'}) { # convert uniq to clean(norm) format
		my $output_file = $input_file;
		$output_file =~ s/\..*$/_norm\.fasta/;
		die "[ERR]Output exist, $output_file\n" if -s $output_file;
		my $out = IO::File->new(">".$output_file) || die $!;

		my ($fh);
		if ($input_file =~ m/\.gz$/) {
			open($fh, '-|', "gzip -cd $input_file") || die $!;
		} else {
			open($fh, $input_file) || die $!;
		}

		while(<$fh>) 
		{
			chomp;
			my $id = $_;
			die "[ERR]seq format $id\n" unless $id =~ m/^>/;
			$id =~ s/^>//;
			my @a = split(/-/, $id);
			my $seq_num = pop @a;
			my $seq_id = join("-", @a);
        		my $seq = <$fh>; chomp($seq);

			for(my $i=1; $i<=$seq_num; $i++)
			{
				my $new_id = $seq_id."_$i";
				print $out ">".$new_id."\n".$seq."\n";
			}
		}

		close($fh);
		$out->close;

	} else {  # convert the clean to uniq 

		my $output_file = $input_file;
		$output_file =~ s/\..*$/_uniq\.fasta/;
		die "[ERR]Output exist, $output_file\n" if -s $output_file;
		
		my ($fh, $format, $total_seq_num, $length);
		if ($input_file =~ m/\.gz$/) {
			open($fh, '-|', "gzip -cd $input_file") || die $!;
		} else {
			open($fh, $input_file) || die $!;
		}

		# load seq/read count to hash
		my %seq_count;
		while(<$fh>)
		{
			chomp; 
			my $id = $_; $id =~ s/ .*//;
			$format = '';
			if ($id =~ m/^>/) { $format = 'fasta'; }
			elsif ($id =~ m/^@/) { $format = 'fastq'; }
			else { die "[ERR]seq fromat: $id\n"; }
		
			my $seq = <$fh>; chomp($seq);
			if ( defined $seq_count{$seq} ) {
				$seq_count{$seq}++;
			} else {
				$seq_count{$seq} = 1;
			}
			
			if ($format eq 'fastq') { <$fh>; <$fh>; }
			$total_seq_num++;
		}
		$fh->close;
		
		$length = length($total_seq_num);

		# sort by num for duplicate seq/read
		my %seq_count_sort;
		foreach my $sq (sort keys %seq_count) {
			my $count = $seq_count{$sq};
			if ($count > 1 ) {
				if (defined $seq_count_sort{$count}) {
					$seq_count_sort{$count}.= "\t".$sq;
				} else {
					$seq_count_sort{$count} = $sq;
				}
				delete $seq_count{$sq};
			} 
		}

		# output result
		my $seq_num = 0;
		my $out = IO::File->new(">".$output_file) || die $!;
		# --- output duplicate seq/read
		foreach my $ct (sort { $b<=>$a } keys %seq_count_sort) { 
			my @seq = split(/\t/, $seq_count_sort{$ct});
			foreach my $sq (@seq) {
				$seq_num++;
				my $zlen = $length - length($seq_num);
				my $z = "0"x$zlen;
				my $seq_id = "sRU".$z.$seq_num;
				print $out ">$seq_id-$ct\n$sq\n";
			}
		}	

		# --- output single seq/read
		foreach my $sq (sort keys %seq_count) {
			$seq_num++;
			my $zlen = $length - length($seq_num);
			my $z = "0"x$zlen;
			my $seq_id = "sRU".$z.$seq_num;
			print $out ">$seq_id-1\n$sq\n";
		}		

		$out->close;
	}
}

=head2
 lengthd -- get length distribution of sRNA 
=cut
sub lengthd
{
	my $options = shift;
	
	my $subUsage = qq'
USAGE: $0 lengthd [options]
        -i      input file 
        -u      input reads file is sRNA clean (default:0) / uniq (1) format

';

	print $subUsage and exit unless $$options{'i'};
	my $input_seq = $$options{'i'};
	my $key = $input_seq; $key =~ s/\..*$//;
	my $output_table = $key.".table";
	my $output_plots = $key.".pdf";
	my $output_image = $key.".png";

	my %length_dist;
	my $seq_num = 0;
	my ($seq_id_info, $seq_id, $seq_desc, $format, $sequence, $seq_length, $uniq_count);
	
	my $fh = IO::File->new($input_seq) || die $!;
	while(<$fh>)
	{
		chomp;
		$seq_id_info = $_;
		if      ($seq_id_info =~ m/^>/) { $format = 'fasta'; $seq_id_info =~ s/^>//; }
		elsif   ($seq_id_info =~ m/^@/) { $format = 'fastq'; $seq_id_info =~ s/^@//; }
		else    { die "[ERR]sRNA ID: $seq_id_info\n"; }
		($seq_id, $seq_desc) = split(/\s+/, $seq_id_info, 2);
		unless ($seq_desc) { $seq_desc = ""; }
		
		$sequence = <$fh>; chomp($sequence);
		$seq_length = length($sequence);

		if ($$options{'u'}) {
			my @nn = split(/-/, $seq_id);
			$uniq_count = $nn[scalar(@nn)-1];
			die "[ERR]sRNA count $seq_id_info, $seq_id, $uniq_count\n" if $uniq_count < 1;
			$seq_num = $seq_num + $uniq_count;

			if ( defined $length_dist{$seq_length} ) { $length_dist{$seq_length} = $length_dist{$seq_length} + $uniq_count; }
			else { $length_dist{$seq_length} = $uniq_count; }
		} else {
			$seq_num++;

			if ( defined $length_dist{$seq_length} ) { $length_dist{$seq_length}++; }
			else { $length_dist{$seq_length} = 1; }
		}

		if ($format eq 'fastq') { <$fh>; <$fh>; }
	}
	$fh->close;

	# output lengt distribution tables
	my $out = IO::File->new(">".$output_table) || die "Can not open output table file $output_table $!\n";
	foreach my $len (sort keys %length_dist) {
		my $freq = sprintf('%.4f', $length_dist{$len}/$seq_num);
		$freq = $freq * 100;
		print $out "$len\t$length_dist{$len}\t$freq\n";
	}
	$out->close;	

	# R code for length distribution
my $R_LD =<< "END";
a<-read.table("$output_table")
x<-a[,1]
y<-a[,2]
dat <- data.frame(fac = rep(x, y))
pdf("$output_plots",width=12,height=6)
barplot(table(dat)/sum(table(dat)), col="lightblue", xlab="Length(nt)", ylab="Frequency", main="Length distribution")
invisible(dev.off())
END

	open R,"|/usr/bin/R --vanilla --slave" or die $!;
	print R $R_LD;
	close R;	

	# convert pdf file to png
	my $cmd_convert = "convert $output_plots $output_image";
	system($cmd_convert) && die "[ERR]CMD: $cmd_convert\n";
}

=head2
 norm -- normalization of sRNA dataset
=cut
sub norm
{
	my $options = shift;
	
	my $subUsage = qq'
USAGE $0 norm [options] 
        -i      list of UNIQUE read
        -o      perfix of output files

* the input file in list MUST be UNIQUE format of sRNA
  the UNIQUE formart include read count in ID.

* the output files
[perfix]_sRNA_expr	raw expression
[perfix]_sRNA_libsize	library size
[perfix]_sRNA_expTPM	normalized exp
[perfix]_sRNA_seq	unique sRNA

';
	print $subUsage and exit unless ($$options{'i'} && $$options{'o'});
	
	my $list_uniq_read = $$options{'i'};
	my $prefix = $$options{'o'};
	my $output1 = $prefix."_sRNA_expr";
	my $output2 = $prefix."_sRNA_libsize";
	my $output3 = $prefix."_sRNA_expTPM";
	my $output4 = $prefix."_sRNA_seq";

	# put list of uniq small RNA reads to array
	my @list;
	my $fh = IO::File->new($list_uniq_read) || die "Can not open list file $list_uniq_read $!\n";
	while(<$fh>)
	{
		chomp;
		push(@list, $_);
		die "[ERR]cat not find uniq read file $_\n" unless -s $_;
	}
	$fh->close;

	# main expression and libsize value to hash
	my %uniq_read;
	my %libsize;	

	foreach my $file (@list)
	{
        	my $total_read = 0;
        	my $fu;
		if ($file =~ m/\.gz$/) {
			open ($fu,'-|', "gzip -cd $$file") || die $!;	# discard gzip IO, method from honghe
        	} else {
                	open($fu, $file) || die $!;
        	}

		while(<$fu>)
		{
                	chomp;
	                my $id = $_;
        	        my @a = split(/-/, $id);
	                my $exp = $a[scalar(@a)-1];
        	        my $seq = <$fu>; chomp($seq);
	                $uniq_read{$seq}{$file} = $exp;
        	        $total_read = $total_read + $exp;
	        }
	        close($fu);
	        $libsize{$file} = $total_read;
	}

	# output the libsize
	my $out2 = IO::File->new(">$output2") || die "Can not open output libsize $output2 $!\n";
	foreach my $k (sort keys %libsize) { print $out2 $k."\t".$libsize{$k}."\n"; }
	$out2->close;

	# output the expression 
	my $out1 = IO::File->new(">$output1") || die "Can not open output expression $output1 $!\n";
	my $out3 = IO::File->new(">$output3") || die "Can not open output expression TPM $output3 $!\n";
	my $out4 = IO::File->new(">$output4") || die "Can not open output small RNA $output4 $!\n";

	print $out1 "#ID\tUniqRead";
	print $out3 "#ID\tUniqRead";
	foreach my $file (@list) {
        		print $out1 "\t".$file;
			print $out3 "\t".$file;
	}
	print $out1 "\n";
	print $out3 "\n";

	my $seq_order = 0;
	my $length = length(scalar(keys(%uniq_read)));

	foreach my $seq (sort keys %uniq_read)
	{
		$seq_order++;
		my $zlen = $length - length($seq_order);
		my $z = "0"x$zlen;
		my $seq_id = "sR".$prefix.$z.$seq_order;

		print $out4 ">".$seq_id."\n".$seq."\n";

		my $line = $seq_id."\t".$seq;
		my $line_tpm = $seq_id."\t".$seq;

		foreach my $file (@list)
		{
			if ( defined $uniq_read{$seq}{$file} )
                	{
                        	$line.="\t$uniq_read{$seq}{$file}";

	                        my $tpm = $uniq_read{$seq}{$file} / $libsize{$file} * 1000000;
        	                $tpm = sprintf("%.2f", $tpm);
                	        $line_tpm.="\t$tpm";
                	}
                	else
                	{
                        	$line.="\t0";
                        	$line_tpm.="\t0";
                	}
        	}

	        print $out1 $line."\n";
	        print $out3 $line_tpm."\n";
	}
	$out1->close;
	$out3->close;
	$out4->close;

}

=head2
 normcut -- normalization of sRNA cutoff
=cut
sub normcut
{
	my $options = shift;
	
	my $subUsage = qq'
USAGE $0 normcut [options]
	-i	input file prefix
	-c	cutoff (default: 10 TPM)

* the input file should be:
[perfix]_sRNA_expr
[perfix]_sRNA_expTPM
[perfix]_sRNA_seq

';

	print $subUsage and exit unless $$options{'i'};
	my $file_prefix = $$options{'i'};
	my $cutoff = 10;
	$cutoff = $$options{'c'} if (defined $$options{'c'} && $$options{'c'} > 0);

	my $expr = $file_prefix."_sRNA_expr";
	my $norm = $file_prefix."_sRNA_expTPM";
	my $srna = $file_prefix."_sRNA_seq";

	my $out_expr = $file_prefix."_".$cutoff."TPM_sRNA_expr";
	my $out_norm = $file_prefix."_".$cutoff."TPM_sRNA_expTPM";
	my $out_sRNA = $file_prefix."_".$cutoff."TPM_sRNA_seq";

	my $out1 = IO::File->new(">".$out_expr) || die $!;
	my $out2 = IO::File->new(">".$out_norm) || die $!;
	my $out3 = IO::File->new(">".$out_sRNA) || die $!;

	my %id;
	my $fh2 = IO::File->new($norm) || die $!;
	my $title = <$fh2>; print $out2 $title;
	while(<$fh2>)
	{
        	chomp;
 		my @a = split(/\t/, $_);

		my $select = 0;
		for(my $i=2; $i<@a; $i++) {
               		if ( $a[$i] > $cutoff ) {
                        	$select = 1;
                	}
        	}

        	if ($select == 1) {
                	$id{$a[0]} = 1;
                	print $out2 $_."\n";
			print $out3 ">$a[0]\n$a[1]\n";
        	}
	}
	$fh2->close;
	$out2->close;
	$out3->close;

	my $fh1 = IO::File->new($expr) || die $!;
	my $t = <$fh1>; print $out1 $t;
	while(<$fh1>)
	{
        	chomp;
		my @a = split(/\t/, $_);
		if ( defined $id{$a[0]} ) { print $out1 $_."\n"; }
	}
	$fh1->close;
	$out1->close;
}

=head2
 combine -- combine sRNA replicate to one sample
=cut
sub combine
{
        my $options = shift;

        my $subUsage = qq'
USAGE $0 combine [options]
        -i      replicate1,replicate2,replicate3,...,repliateN
        -o      output_prefix (defaule: sRcombine)

* the input replicate should be uniq sRNA with fasta format
* the output file will be sRcombine.fasta, and sRNA ID start with sRcombine.

';

        print $subUsage and exit unless $$options{'i'};
	
	# check input files;
	my @inFiles = split(/,/, $$options{'i'});
	foreach my $f (@inFiles) {
		die "[ERR]File $f is not exist\n" unless -s $f;
	}

	# output file
	my $out_prefix = 'sRcombine';
	$out_prefix = $$options{'o'} if $$options{'o'};
	my $output_file = $out_prefix.".fasta";
	die "[ERR]output file $output_file exist\n" if -s $output_file;

	# put sRNA count to hash
	my %sRNA_count;

	foreach my $f (@inFiles) 
	{
		my $fh = IO::File->new($f) || die $!;
		while(<$fh>)
		{
			chomp;
			my $id = $_; 
			die "[ERR]seq id $id in file $f\n" unless $id =~ m/^>/;
			my @a = split(/-/, $id);
			my $ct = $a[scalar(@a)-1];
			die "[ERR]seq num $ct\n" if $ct < 1;
			my $seq = <$fh>; chomp($seq);

			if (defined $sRNA_count{$seq}) {
				$sRNA_count{$seq} = $sRNA_count{$seq} + $ct;
			} else {
				$sRNA_count{$seq} = $ct;
			}
		}
		$fh->close;
	}

	my $length = length(scalar(keys(%sRNA_count)));

	my $out = IO::File->new(">".$output_file) || die $!;
	my $s_num = 0;
	foreach my $sRNA (sort keys %sRNA_count)
	{
		my $ct = $sRNA_count{$sRNA};
		$s_num++;
		my $zlen = $length - length($s_num);
		my $z = "0"x$zlen;
		my $sid = $out_prefix.$z.$s_num."-".$ct;
		print $out ">$sid\n$sRNA\n";
	}
	$out->close;
}

=head2
 usage -- print usage information
=cut
sub usage
{
	print qq'
Program: sRNAtools (Tools for sRNA analysis)
Version: $version

USAGE: $0 <command> [options] 
Command: 
	chkadp		check adapter sequence (kmer method)
	rmadp3		remove 3p adapter sequence
	rmadp5		remove 5p adapter sequence
	convert		convert between table format and fastq/fasta format
	unique		convert between unique format and clean format
	norm	     	normalization (RPM)
	normcut		normalization cutoff	
	lengthd		length distribution of sRNA	
	combine		combine sRNA replicates
	
';
	exit;
}


