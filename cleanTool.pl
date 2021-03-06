#!/usr/bin/perl

=head1
 cleanTool.pl -- tools for clean NGS reads
=cut
use strict;
use warnings;
use IO::File;
use FindBin;
use Getopt::Std;

my $version = 0.1;
my $debug = 0;

my %options;
getopts('a:b:c:d:e:f:g:i:j:k:l:m:n:o:p:q:r:s:t:u:v:w:x:y:z:h', \%options);
unless (defined $options{'t'} ) { usage($version); }

# checking parameters
if	($options{'t'} eq 'pass')	{ clean_pass(\%options, \@ARGV); }	# pass the illumina quality check 
elsif	($options{'t'} eq 'adpchk')	{ clean_adpchk(\%options, \@ARGV); }	# parse single/paired files
elsif	($options{'t'} eq 'trimo')	{ clean_trimo(\%options, \@ARGV); }	# parse multi dataset
elsif	($options{'t'} eq 'align')	{ clean_align(\%options, \@ARGV); }	# parse multi dataset
elsif	($options{'t'} eq 'barcode')	{ clean_barcode(\%options, \@ARGV); }
elsif   ($options{'t'} eq 'bunmatch')	{ clean_barcode_unmatch(\%options, \@ARGV); }	# parse unmatch barcode file
elsif   ($options{'t'} eq 'pipeline')	{ pipeline(); }
else	{ usage($version); }
#################################################################
# kentnf: subroutine						#
#################################################################

=head2
 clean_pass: filter out unpassed reads
=cut
sub clean_pass
{
	my ($options, $files) = @_;
	my $usage = qq'
USAGE $0 -t pass input_file_R1 [input_file_R2]

';
	print $usage and exit unless defined $$files[0];
	
	foreach my $f (@$files) {
		die "[ERR]file not exist $f\n" unless -s $f;
	}

	foreach my $f (@$files) {

		my $out_file = "pass_".$f;
		die "[ERR]output file exist $out_file\n" if -s $out_file;
		my $fho;
		if ($out_file =~ m/\.gz$/) {
			open($fho, "| gzip -c > $out_file") || die $!;
		} else {
			open($fho, ">".$out_file) || die $!;
		}


		my $fh;
		if ($f =~ m/\.gz$/) {
                        open($fh, '-|', "gzip -cd $f") || die $!;
                } else {
                        open($fh, $f) || die $!;
		}

		my ($format, $id, $seq, $id2, $qul, $out, $total, $pass);
		$total = 0; $pass  = 0;
		while(<$fh>) {
			my $id = $_;
			
			if ( $id =~ m/^@/ ) {
				$format = 'fq';
			} elsif ($id =~ m/^>/) {
				$format = 'fa';
			} else {
				die "[ERR]format $id";
			}
			
			$seq = <$fh>;
			$out = $id.$seq;
			
			$total++;

			if ($format eq 'fq') {
				$out .= <$fh>;
				$out .= <$fh>;
			}

			if ( $id =~ m/ 1:N:/) {
				print $fho $out;
				$pass++;
			} 
		}
		close($fh);
		close($fho);

		print "$f\t$total\t$pass\n";
	}
}

=head2
 adpchk -- check adapter for RNASeq
=cut 
sub clean_adpchk
{
	my ($options, $files) = @_;
	my $usage = qq'
USAGE $0 -t adpchk -y read_yeild (default:1M) input_file_R1 [input_file_R2]

';
	print $usage and exit unless defined $$files[0];
	die "[ERR]file not exist\n" unless -s $$files[0];

	my $yeild_read = 1000000;
	$yeild_read = $$options{'y'} if defined $$options{'y'};	

	# description of adapter (according to trimmomatic)
	# +++ TruSeq2 +++
	# AGATCGGAAGAGC TCGTATGCCGTCTTCTGCTTG 	TruSeq2_SE
	# AGATCGGAAGAGC GTCGTGTAGGGAAAGAGTGT	TruSeq2_PE_f, PCR_Primer1_rc, Universal
	# AGATCGGAAGAGC GGTTCAGCAGGAATGCCGAG	TruSeq2_PE_r, PCR_Primer2_rc
	# +++ TruSeq3 +++
	# AGATCGGAAGAGC ACACGTCTGAACTCCAGTCAC	TruSeq3_SE,PE2_rc
	# AGATCGGAAGAGC GTCGTGTAGGGAAAGAGTGTA	TruSeq3_UniversalAdapter,PE1_rc

	# description of sRNA/dRNA adapters (according to prev sRNA/dRNA dataset)
	# +++ sRNA 01 +++
	# CTGTAGGCACCATCAAT AGATCGGAAGAGCACACGTCTGAACTCCAGTCACTCTCGTATGCCGTCTTCTGCTTG -- most common sRNA adp 
	# CTGTAGGCACCATCAAT CT  -- XiaoFang/Silin
	# +++ sRNA 02 +++ TrueSeq3_SE,PE2_rc+5'C ++
	# CAGATCGGAAGAGCACACGTCTGAACTCCAGTCACATCACGAT -- Illumina Multiplexing PCR Primer 2.0
	# +++ sRNA 03-06 +++
	# TCGTATGCCGTCTTCTGCTTG -- wild rice
	# TGGAATTCTCGGGTGCCAAGGAACTCCAGTCAC -- 
	# ATCTCGTATGCCGTCTTCTGCTTG ??? 
	# GTACCTCGTATGCCGTCTT	-- Silin

	# +++ dRNA +++
	# CTGCTGGATCGTCGGACTGTAGAACTCTG -- Ying's dRNA

	# +++ construct adapter hash +++
	# key: adp name value: adp seq
	my %adp;
	$adp{'TruSeq2-SE'} = 'AGATCGGAAGAGCTCGT';
	$adp{'TruSeq2-PE'} = 'AGATCGGAAGAGCGGTT';
	$adp{'TruSeq3'}    = 'AGATCGGAAGAGCACAC';
	$adp{'TruSeq-Uni'} = 'AGATCGGAAGAGCGTCG';
	$adp{'sRNA01'} 	   = 'CTGTAGGCACCATCAAT';
	$adp{'sRNA02'}     = 'CAGATCGGAAGAGCACA';
	$adp{'sRNA03'}     = 'TCGTATGCCGTCTTCTG';
	$adp{'sRNA04'}     = 'TGGAATTCTCGGGTGCC';
	$adp{'sRNA05'}     = 'ATCTCGTATGCCGTCTT';
	$adp{'sRNA06'}     = 'GTACCTCGTATGCCGTC';	
	$adp{'dRNA01'}     = 'CTGCTGGATCGTCGGAC';

	# check adapters
	print "#adpName\tadpSequence\tTotalMatch\tA\tT\tC\tG\n";

	foreach my $f (@$files) {
		warn "[WARN]file not exist\n" and next unless -s $f;
		
		# create adp count hash;
		my %adp_count;
		foreach my $adp_name (sort keys %adp) {
			$adp_count{$adp_name}{'match'} = 0;
			$adp_count{$adp_name}{'baseA'} = 0;
			$adp_count{$adp_name}{'baseT'} = 0;
			$adp_count{$adp_name}{'baseC'} = 0;
			$adp_count{$adp_name}{'baseG'} = 0;
		}

		# count adp
		my $count = 0;
		my $format;
		my $fh;
		if ($f =~ m/\.gz$/) {
			open($fh, '-|', "gzip -cd $f") || die $!;
		} else {
			open($fh, $f) || die $!;
		}

		while(<$fh>) {
			my $id1 = $_;	chomp($id1);
			my $seq = <$fh>;chomp($seq);
			if ( $id1=~m/^@/ ) { $format='fastq'; }
			if ( $id1=~m/^>/ ) { $format='fasta'; }
			if ($format eq 'fastq') { <$fh>; <$fh>; }
			$count++;
			$seq = uc($seq);

			foreach my $adp_name (sort keys %adp) {
				my $adp_seq = $adp{$adp_name};
				$adp_count{$adp_name}{'match'}++ if $seq =~ m/\Q$adp_seq\E/;
				$adp_count{$adp_name}{'baseA'}++ if $seq =~ m/A\Q$adp_seq\E/;
				$adp_count{$adp_name}{'baseT'}++ if $seq =~ m/T\Q$adp_seq\E/;
				$adp_count{$adp_name}{'baseC'}++ if $seq =~ m/C\Q$adp_seq\E/;
				$adp_count{$adp_name}{'baseG'}++ if $seq =~ m/G\Q$adp_seq\E/;
			}	

			last if $count == $yeild_read;
		}
		$fh->close;

		print "=== $f ===\n";
		foreach my $adp_name (sort keys %adp_count) {
			print $adp_name."\t".$adp{$adp_name}."\t".$adp_count{$adp_name}{'match'}."\t".
				$adp_count{$adp_name}{'baseA'}."\t".
				$adp_count{$adp_name}{'baseT'}."\t".
				$adp_count{$adp_name}{'baseC'}."\t".
				$adp_count{$adp_name}{'baseG'}."\n";
		}
	}	
}

=head2
 barcode_unmatch -- 
=cut
sub clean_barcode_unmatch
{
	my ($options, $files) = @_;
	my $usage = qq'
USAGE $0 -t barcode_unmatch -n [barcode length] unmatch.txt > report_unmatch_barcode.txt

 * the default length is 6
 
';
	print $usage and exit unless defined $$files[0];
	my $unmatch_file = $$files[0];
	die "[ERR]file not exist\n" unless -s $unmatch_file;

	my $barcode_length = 6;
	$barcode_length = $$options{'n'} if (defined $$options{'n'} && $$options{'n'} > 0);

	my %h; # key: barcode, value: count
	my $fh = IO::File->new($unmatch_file) || die $!;
	while(<$fh>)
	{
        	my $id = $_;		chomp($id);
        	my $seq = <$fh>;	chomp($seq);
		if ($id =~ /^@/) { <$fh>; <$fh>; }
		elsif ($id =~ m/^>/) { } 
		else { die "[ERR]seq format: $id\t$seq\n"; }
        	my $sub = substr($seq, 0, $barcode_length);
        	$h{$sub}++ if defined $h{$sub};
		$h{$sub} = 1 unless defined $h{$sub};
	}

	# convert %h to %c
	# key: count, value: array of barcode
	my %c;
	foreach my $s (sort keys %h) {
		my $count = $h{$s};
		if (defined $c{$count}) {
			$c{$count}.= "\t".$s;
		} else {
			$c{$count} = $s;
		}
	}

	# output result
	foreach my $count (sort {$b<=>$a} keys %c) {
		my @b = split(/\t/, $c{$count});
		foreach my $b (@b) {
			print "$b\t$count\n";
		}
	}
	
}

=head2
 barcode -- split reads according to barcode, remove barcode
=cut
sub clean_barcode
{
	my ($options, $files) = @_;
	my $usage = qq'
USAGE $0 -t barcode -m mismatch(default:0) barcode_file input_reads

* format of barcode file
output_file_name1 [tab] bacode1
output_file_name2 [tab] bacode2
......

';
	# check input files
	print $usage and exit if (scalar(@$files) < 2);
	my ($barcode_file, $input_file) = ($$files[0], $$files[1]);
	print "[ERR]no file $barcode_file\n" and exit unless -s $barcode_file;
	print "[ERR]no file $input_file\n" and exit unless -s $input_file;

	my $cutoff = 0;
	$cutoff = $$options{'m'} if (defined $$options{'m'} && $$options{'m'} < 3);
	
	# define output file
	my $pre_name = $input_file;
	$pre_name =~ s/\.txt//g; $pre_name =~ s/\.gz//g;
	my $unmatch_file = $pre_name ."_unmatch.txt";
	my $ambiguous_file = $pre_name . "_ambiguous.txt";
	my $out1 = IO::File->new(">$unmatch_file") || die "Can't open unmatch output file\n";
	my $out2 = IO::File->new(">$ambiguous_file") || die "Can't open ambiguous output file\n";

        my $i = 0;
	my %tag_info;
	my @barcode;
	my $OUT;
	my $in1 = IO::File->new($barcode_file) || die "Can't open the barcode file\n";
	while(<$in1>)
	{
        	chomp;
		next if $_ =~ m/^#/;
		my @a = split(/\t/);
		$tag_info{$a[1]}{'file'} = $a[0];
		$tag_info{$a[1]}{'num'} = 0;
		push(@barcode, $a[1]);
		
		# Create file for each tag
		$i++;
		#my $out = $OUT.$i;
		my $out;
        	open($out, ">$a[0]") || die "can't create $a[0] $!\n";
		$tag_info{$a[1]}{'fh'} = $out;
	}
	$in1->close;

	# parse raw fastaq file
	my ($in2, $id1, $id2, $seq, $qul, $modified_seq, $modified_qul);
	my $tag_result = '';
	my ($unmatch_num, $ambiguous_num) = (0, 0);
	if ($input_file =~ m/\.gz$/) {
		open($in2, "gunzip -c $input_file |") || die "Can't open the fastq file\n";
	} else {
		open($in2, $input_file) || die "Can't open the fastq file\n";
	}

	while(<$in2>) 
	{
		$id1 = $_;      chomp($id1);
		$seq = <$in2>;   chomp($seq);
		$id2 = <$in2>;   chomp($id2);
		$qul = <$in2>;   chomp($qul);

		# compare seq with barcode
		my $best_mismatch = 3;
		my %best_tag_result = ();

		foreach my $elements ( @barcode ) {
        		my $len = length($elements);
			next if length($seq) < $len;
			my $read_substr = substr($seq, 0, $len);

			# old method 
			if ($cutoff == 0) {
				my $m = 0;
                		for( my $i = 0; $i< $len; $i++ ) {
                        		if(substr($elements, $i, 1) eq substr($read_substr, $i, 1) ) {
						$m++;
                        		}
				}
				$tag_result.= "%".$elements if $m == $len;
			} 
			# new method, haming distance
			else 
			{
				my $mismatch = hamming($read_substr, $elements);
				if ($mismatch <= $cutoff) {
					$best_mismatch = $mismatch if ($mismatch < $best_mismatch);
					if (defined $best_tag_result{$mismatch}) {
						$best_tag_result{$mismatch}.= "%".$elements;
					} else {
						$best_tag_result{$mismatch} = "%".$elements;
					}
				}
			}
		}
		$tag_result = $best_tag_result{$best_mismatch} if ($cutoff > 0 && $best_mismatch < 3);

		if($tag_result eq "") { 				# Print unmatch seq.
			print $out1 $id1."\n".$seq."\n".$id2."\n".$qul."\n";
			$unmatch_num++;
                } elsif($tag_result =~ /%[ACGTN]*%[ACGTN]*$/) {		# Print ambiguous seq.
                        print $out2 $id1."$tag_result\n".$seq."\n".$id2."\n".$qul."\n";
			$ambiguous_num++;
                } else {						# Print for other non-ambiguous tags
                        $tag_result =~ s/%//g;
                        my $fileH = $tag_info{$tag_result}{'fh'};
			$tag_info{$tag_result}{'num'}++;
                        $modified_seq = substr($seq,length($tag_result), );
                        $modified_qul = substr($qul,length($tag_result), );
                        print $fileH $id1."\n".$modified_seq."\n".$id2."\n".$modified_qul."\n";
                }
                $tag_result = "";
	}
	$out1->close;
	$out2->close;

	foreach my $elements (@barcode) {
        	my $fileH = $tag_info{$elements}{'fh'};
		close($fileH);
		print $tag_info{$elements}{'file'},"\t",$tag_info{$elements}{'num'},"\n";
	}

	print $ambiguous_file."\t".$ambiguous_num."\n";
	print $unmatch_file."\t".$unmatch_num."\n";
}

sub hamming($$) { length( $_[ 0 ] ) - ( ( $_[ 0 ] ^ $_[ 1 ] ) =~ tr[\0][\0] ) }

=head2
 trimo -- clean reads using trimmomatic
=cut
sub clean_trimo
{
	my ($options, $files) = @_;
	my $usage = qq'
USAGE $0 -t trimo [options] sample1_R1 ... sampleN_R1 | sample1_R1,sample1_R2 ... sampleN_R1,sampleN_R2

'; 

	# checking trimmomatic and adapter sequence
	my ($trim_bin, $adp_SE, $adp_PE);
	$trim_bin = ${FindBin::RealBin}."/bin/trimmomatic0.32.jar";
	$adp_SE = ${FindBin::RealBin}."/bin/adapters/TruSeq3-SE.fa";
	$adp_PE = ${FindBin::RealBin}."/bin/adapters/TruSeq3-PE.fa";
	my @require_files = ($trim_bin, $adp_SE, $adp_PE);
	
	foreach my $f (@require_files) {
		print "[ERR]no file $f\n" and exit unless -s $f;
	}
	
	my $qual = 15; my $score = 7; my $seed_mismatch = 2; my $min_len = 40; my $thread = 24;
	$qual = $$options{'q'} if defined $$options{'q'}  && $$options{'q'} >= 10;
	$thread = $$options{'p'} if defined $$options{'p'} && $$options{'p'} > 0;
	
	# check input files
	my @input_files;
	foreach my $f ( @$files ) 
	{
		if ($f =~ m/,/) 
		{
			my @a = split(/,/, $f);
			print STDERR "[ERR]file $a[0] or $a[1] not exist\n" and next unless (-s $a[0] && -s $a[1]);
			push(@input_files, $f);
		}
		else
		{
			print STDERR "[ERR]file $f not exist\n" and next unless -s $f;
			push(@input_files, $f);
		}

	}
	die "$usage\n" if (scalar(@input_files) == 0);

	# trim adapter lowqual
	my ($ss, $clip, $inout, $outprefix, $cmd); 
	foreach my $f (@input_files) 
	{
		if ($f =~ m/,/) {
			my @a = split(/,/, $f);
			$outprefix = $a[0];
			$outprefix =~ s/\.gz//;
			$outprefix =~ s/\.fq//; $outprefix =~ s/\.fastq//;
			$outprefix =~ s/_R1//;  $outprefix =~ s/_1//;
			my ($p1, $p2, $s1, $s2) = ($outprefix."_paired_R1.fastq", $outprefix."_single_R1.fastq", $outprefix."_paired_R2.fastq", $outprefix."_single_R2.fastq");
			$inout = "$a[0] $a[1] $p1 $p2 $s1 $s2";
			$ss = 'PE';
			$clip = "ILLUMINACLIP:$adp_PE:$seed_mismatch:30:$score:1:true";
		} else {
			$outprefix = $f;
			$outprefix =~ s/\.gz//;
			$outprefix =~ s/\.fq//; $outprefix =~ s/\.fastq//;
			$inout = "$f $outprefix"."_clean.fastq";
			$ss = 'SE';
			$clip = "ILLUMINACLIP:$adp_SE:$seed_mismatch:30:$score";
		}
		$cmd = "java -jar $trim_bin $ss -threads $thread -phred33 $inout $clip LEADING:3 TRAILING:3 SLIDINGWINDOW:4:$qual MINLEN:$min_len";
		print $cmd."\n";
	}

}

=head2
 align -- clean reads through align reads
=cut
sub clean_align
{

}

=head2
 usage: print usage information
=cut
sub usage
{
	print qq'
USAGE: $0 -t [tool] [options] input file

	pass		only keep reads pass Illumina quality
	adpchk		check adapter sequence
	trimo		trim adapter, low quality, and short reads using trimmomatic.	
	barcode		remove barcode and split file according to barcode
	bunmatch	count the number of unmatched barcode

';
	exit;
}

=head2
 usage: print pipeline or command 
=cut
sub pipeline
{
	print qq'
>> pipeline for $0
>> A. remove barcode
	\$ $0 -t barcode barcode_file input.fastq.gz

>> 1. clean mRNA
      	1.1 clean adapter, low quality, short reads
	\$ $0 -t trimo sample1_R1.fastq ... sampleN_R1.fastq | sample1_R1.fastq,sample1_R2.fastq ... sampleN_R1.fastq,sampleN_R2.fastq
	1.2 clean rRNA or other contanmination
	\$ $0 -t align -r reference -m 0 -v 0 -k 1 *.fastq
	
>> 2. clean sRNA/degradome
	2.1 clean adapter, short reads,
	2.2 clean rRNA or other contanmination

>> 3. clean DNA
	3.1 clean adapter, low quality, short reads

';
	exit;
}
