#!/usr/local/bin/perl -w
# $Id$

# Japan/MARC�ե�������ɤ߹��ߡ��ʲ���2�ĤΥϥå����DBM�ե�����˳�Ǽ���롣
# 	JP-No �� �ե�����̾
# 	JP-No �� �ե�������γ��ϰ���

# �¹���:
# ./jpno-index.pl /project/jmarc/Original/[0-9][0-9][0-9][0-9][0-9][0-9]

use strict;
use FileHandle;
use File::Basename;
use NDBM_File;

require 'jmarc.pl';

my %filename; # �ե�����̾��Ͽ���롣
my %position; # �ե����뤫��γ��ϰ��֤�Ͽ���롣

main();
sub main {
    if ($#ARGV < 0) {
	print "�Ȥ���: $0 �ե����� ...\n";
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
	    warn "�ե����뤬���Ĥ���ޤ���: $file";
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
