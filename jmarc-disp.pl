#!/usr/local/bin/perl -w

use strict;
require 'jmarc.pl';

my $MARC_PREFIX = '/project/jmarc/Original';

main();
sub main {
    if (!defined $ARGV[0]) {
	print "�Ȥ���: $0 JP�ֹ�\n";
	exit 0;
    }
    my $jpno = $ARGV[0];
    my %filename; # �ե�����̾
    my %position; # �ե�������γ��ϰ���

    dbmopen(%filename, "jp-fname", 0444);
    dbmopen(%position, "jp-pos", 0444);
    
    if (defined $filename{$jpno}) {
	my $fname = "$MARC_PREFIX/$filename{$jpno}";
	if (! -f $fname) {
	    print "�ե����뤬���Ĥ���ޤ���: ($fname)\n";
	    exit 1;
	}

	my $record = read_record($fname, $position{$jpno});

        my $label = jmarc::get_label($record);
        my $directory = jmarc::get_directory($record);
	my %fields = jmarc::get_fields($record);
	print "$label\n$directory\n\n";
	foreach my $fid (sort keys %fields) {
            if ($fid eq "001") {
                print "$fid  $fields{$fid}\n";
                next;
            }
            foreach my $subfield (@{$fields{$fid}}) {
                while (my ($sub_fid, $value) = each %{$subfield}) {
                    print "$fid \$$sub_fid $value\n";
                }
            }
        }
    } else {
	print "JP�ֹ� $jpno ��¸�ߤ��ʤ������������Ƥ��ޤ���\n";
	exit 1;
    }
    dbmclose(%filename);
    dbmclose(%position);
}

sub read_record($$) {
    my ($filename, $position) = @_;
    open(MARC, $filename) || die "open fail MARC ($filename): $!";

    my $tmp = undef;
    seek MARC, $position, 0;
    read MARC, $tmp, 5 ||
	die "read fail MARC ($filename, $position): $!";
    my $length = int jmarc::ebcdic2ascii($tmp);
	
    seek MARC, $position, 0;
    read MARC, $tmp, $length-1 ||
	die "read fail MARC ($filename, $position): $!";

    return $tmp;
}
