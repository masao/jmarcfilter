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

# JIS X 0208 漢字をエスケープコードを含めて返す。
# 同時に、外字の処理も行なう。
sub escape_kanji($) {
    my ($data) = @_;
    
    # 一応、長音のローマ字形(a^i^u^e^o^, etc.)は通常のアルファベットに戻す。
    my %GAIJI = ("\x2a\x23" => "#A", # Ａ
                 "\x2a\x2f" => "#I", # Ｉ
                 "\x2a\x39" => "#U", # Ｕ
                 "\x2a\x2b" => "#E", # Ｅ
                 "\x2a\x34" => "#O", # Ｏ
                 "\x2a\x43" => "#a", # ａ
                 "\x2a\x56" => "#i", # ｉ
                 "\x2a\x6c" => "#u", # ｕ
                 "\x2a\x50" => "#e", # ｅ
                 "\x2a\x5e" => "#o"  # ｏ
		 # "\x22\x31" => "\x21\x21" # ／
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

	# その他の外字は全て全角空白にする。
        $kanji =~ s/[\x30-\x7e][\xa1-\xfe]/\x21\x21/;
        $kanji =~ s/[\x29-\x2f][\x21-\x7e]/\x21\x21/;
        $kanji =~ s/[\x22][\x2f-\x68]/\x21\x21/;

        $str .= $kanji;
    }

    # 直前の文字がカタカナ(or 平仮名)の場合、
    ## 例: データベース、あっかんべー etc.
    # マイナス(−: \x21\x5d)を長音(ー: \x21\x3c)に戻す。
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
