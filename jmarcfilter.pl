#!/usr/local/bin/perl -w
#
# $ID: $
#

use strict;
use Convert::EBCDIC;

my $DEBUG = 0;
$| = 1;

&main();

sub debug_print($) {
    my ($str) = @_;

    if ($DEBUG) {
	print "$str";
    }
}

# JIS X 0208 �����򥨥������ץ����ɤ�ޤ���֤���
# Ʊ���ˡ������ν�����Ԥʤ���
sub escape_kanji($) {
    my ($data) = @_;
    
    # �����Ĺ���Υ��޻���(a^i^u^e^o^, etc.)���̾�Υ���ե��٥åȤ��᤹��
    my %GAIJI = ("\x2a\x23" => "#A", # ��
                 "\x2a\x2f" => "#I", # ��
                 "\x2a\x39" => "#U", # ��
                 "\x2a\x2b" => "#E", # ��
                 "\x2a\x34" => "#O", # ��
                 "\x2a\x43" => "#a", # ��
                 "\x2a\x56" => "#i", # ��
                 "\x2a\x6c" => "#u", # ��
                 "\x2a\x50" => "#e", # ��
                 "\x2a\x5e" => "#o"  # ��
		 # "\x22\x31" => "\x21\x21" # ��
                 );

    my $str = '';

    while (length($data)) {
        die "Length is Odd.\n" if (length($data) == 1);
        my $kanji = substr($data, 0, 2);
        $data = substr($data, 2);
        foreach my $key (keys %GAIJI) {
            if ($kanji eq "$key") {
                $kanji = $GAIJI{$key};
            }
        }

	# ����¾�γ������������Ѷ���ˤ��롣
        $kanji =~ s/[\x30-\x7e][\xa1-\xfe]/\x21\x21/;
        $kanji =~ s/[\x29-\x2f][\x21-\x7e]/\x21\x21/;
        $kanji =~ s/[\x22][\x2f-\x68]/\x21\x21/;

        $str .= $kanji;
    }

    # ľ����ʸ������������(or ʿ��̾)�ξ�硢
    ## ��: �ǡ����١��������ä���١� etc.
    # �ޥ��ʥ�(��: \x21\x5d)��Ĺ��(��: \x21\x3c)���᤹��
    $str =~ s/([\x24-\x25][\x21-\x76])\x21\x5d/$1\x21\x3c/g;

    # JIS X 0208-1978 ( JIS C 6328 97 ) escape sequence.
    return "\x1b\x24\x40$str\x1b\x28\x42";
}

sub main {
    my @tmp = <>;
    my $contents = join('', @tmp);
    my @records = split(/\x1d/, $contents);
    
    my $t = new Convert::EBCDIC;

    debug_print("Total $#records records found.\n");

    foreach my $record (@records) {
	my $length = length $record;
	my $label = $t->toascii(substr($record, 0, 24));
	my $data = substr($record, 24);
	my @fields = split(/\x1e/, $data);
	my $directory = $t->toascii(shift(@fields));

	debug_print "Record : $length ($#fields fields)\n";
	debug_print "Label: $label\n";
	debug_print "Directory: $directory\n\n";

	foreach my $field (@fields) {
	    if (length($directory) < 12) {
		debug_print "ERROR: Directory is mismatch.\n";
	    }
	    my $field_id = substr($directory, 0, 3);
	    my $field_len = substr($directory, 3, 4)+0;
	    my $field_start = substr($directory, 7, 5)+0;
	    $directory = substr($directory, 12);

	    debug_print "ID: $field_id, Length: $field_len, Offset: $field_start\n";
	    if ($field !~ /^\x1f/) {
		print "$field_id  ".$t->toascii($field)."\n";
	    } else {		# This field is SubField
		my @subfields = split(/\x1f/, $field);
		debug_print "Subfield: $#subfields\n";
		foreach my $subfield (@subfields) {
		    if (length($subfield) < 5) {
			debug_print "ERROR: Length of subfield ($subfield) is mismatch.\n";
			next;
		    }
		    my $sub_id = $t->toascii(substr($subfield, 0, 1));
		    my $mode = $t->toascii(substr($subfield, 4, 1));
		    $subfield = substr($subfield, 5, length($subfield));
		    if ($mode eq "1") {
			print "$field_id \$$sub_id  ".$t->toascii($subfield)."\n";
		    } elsif ($mode eq "2") {
			print "$field_id \$$sub_id  ".escape_kanji($subfield)."\n";
		    } else {
			debug_print "mode recognized mismatch: $mode\n";
		    }
		}
	    }
#	    print "\n";
	}
	print "\n";
    }
}
