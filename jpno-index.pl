#!/usr/local/bin/perl -w
# $Id$

# Japan/MARCファイルを読み込み、以下の2つのハッシュをDBMファイルに格納する。
# 	JP-No → ファイル名
# 	JP-No → ファイル中の開始位置

# 実行例:
# ./jpno-index.pl /project/jmarc/Original/[0-9][0-9][0-9][0-9][0-9][0-9]

use strict;
use FileHandle;
use File::Basename;
use NDBM_File;

require 'jmarc.pl';

my %filename; # ファイル名を記録する。
my %position; # ファイルからの開始位置を記録する。

main();
sub main {
    if ($#ARGV < 0) {
	print "使い方: $0 ファイル ...\n";
	exit 1;
    }
    dbmopen(%filename, "jp-fname", 0644);
    dbmopen(%position, "jp-pos", 0644);
    foreach my $file (@ARGV) {
	if (-f $file) {
	    print $file;
	    store_info($file);
	    print "\n";
	} else {
	    warn "ファイルが見つかりません。: $file";
	}
    }
    dbmclose(%filename);
    dbmclose(%position);
}

sub store_info($) {
    my ($path) = @_;

    my $file = basename($path);
    my $pos = 0;

    my $contents = readfile($path);
    my @records = jmarc::get_records($contents);

    foreach my $record (@records) {
        my $length = length($record);
	my $jpno = jmarc::get_jpno($record);
	my $status = jmarc::get_status($record);
	if ($status eq $jmarc::DELETE) {
	    delete $filename{$jpno};
	    delete $position{$jpno};
	} else {
	    $filename{$jpno} = $file;
	    $position{$jpno} = $pos;
	}
	$pos += $length + 1;
    }
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
