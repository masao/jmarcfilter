#!/usr/local/bin/perl -w
#
# $Id$
#
# JAPAN/MARCレコードを読んで、
# 「新規」「修正」「削除」の各レコード件数を集計する。

use strict;

use FileHandle;
use File::Basename;

$| = 1;

require 'jmarc.pl';

my $Csv = undef;

main();
sub main {
    my @files = parse_options();

    print "ファイル名,総数,新規,訂正,削除,,\n" if $Csv;
    
    foreach my $file (@files) {
	my $contents = readfile($file);

	my @records = jmarc::get_records($contents);
	my $total = $#records+1;

	$file = basename($file);
	my %status = ($jmarc::NEW => 0,
		      $jmarc::CHANGE => 0,
		      $jmarc::DELETE => 0);

	my $MinJpno = undef;
	my $MaxJpno = undef;

	foreach my $record (@records) {
	    my $ncd = jmarc::get_status($record);
 	    my $jpno = jmarc::get_jpno($record);
	    
	    if ($ncd eq $jmarc::NEW ||
		$ncd eq $jmarc::CHANGE ||
		$ncd eq $jmarc::DELETE) {
		$status{$ncd}++;
	    } else {
		print STDERR "  不明レコード発見 ($ncd): $jpno\n";
		next;
	    }
	    if (!defined $MaxJpno || jpnocmp($jpno, $MaxJpno) > 0) {
		$MaxJpno = $jpno;
	    }
	    if (!defined $MinJpno || jpnocmp($jpno, $MinJpno) < 0) {
		$MinJpno = $jpno;
	    }
	}
	if ($Csv) {
	    print "$file,$total,$status{$jmarc::NEW},$status{$jmarc::CHANGE},$status{$jmarc::DELETE},JP$MinJpno,JP$MaxJpno";
	} else {
	    print "ファイル名: $file\n";
	    print "レコード総数: $total\n";
	    print "新規: $status{$jmarc::NEW}\n";
	    print "訂正: $status{$jmarc::CHANGE}\n";
	    print "削除: $status{$jmarc::DELETE}\n";
	    print "JP番号: JP$MinJpno 〜 JP$MaxJpno\n";
	}
	print "\n";
    }
}

# JP番号同士の比較を行う。
sub jpnocmp($$) {
    my ($x, $y) = @_;

    $x =~ s/^2/12/;
    $y =~ s/^2/12/;
    return $x <=> $y;
}

sub parse_options() {
    while (defined $ARGV[0] && $ARGV[0] =~ /^-/) {
	if ($ARGV[0] eq "-csv") {
	    $Csv = 1;
	} else {
	    usage();
	}
	shift @ARGV;
    }
    if ($#ARGV < 0) {
	usage();
    }
    return @ARGV;
}
	    
sub usage() {
    print "使い方: $0 [-csv] ファイル名 ...\n";
    exit 1;
}

sub readfile($) {
    my ($fname) = @_;

    my $fh = new FileHandle;
    $fh->open($fname) || die "$fname: $!";

    my $cont = '';
    my $size = -s $fh;
    read $fh, $cont, $size;

    $fh->close();
    return $cont;
}
