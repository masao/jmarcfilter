#!/usr/local/bin/perl -w
#
# This program convert JAPAN/MARC raw data to Dublin Core/RDF data.
#

use strict;
use Convert::EBCDIC;
use Cwd;
use IO::File;
use Getopt::Long;

my $DEBUG = 0;
$| = 1;

# ���ϥե�����Υǥ��쥯�ȥ�
my $OUTDIR = cwd();

# ʣ���ν����ܤ�Bag��Container�����뤫?
## -B or --bag �����椹�롣
my $BagOpt = 0;

main();

sub debug_print($) {
    my ($str) = @_;

    if ($DEBUG) {
	print "$str";
    }
}

# JIS X 0208 �����򥨥������ץ����ɤ�ޤ���֤���
# Ʊ���ˡ������ν�����Ԥʤ���
# �����Ĺ���Υ��޻���(a^i^u^e^o^, etc.)�ϥ���ե��٥åȤ��᤹��
sub escape_kanji($) {
    my ($data) = @_;
    my %GAIJI = ("\x2a\x23" => "#A", # ��
		 "\x2a\x2f" => "#I", # ��
		 "\x2a\x39" => "#U", # ��
		 "\x2a\x2b" => "#E", # ��
		 "\x2a\x34" => "#O", # ��
		 "\x2a\x43" => "#a", # ��
		 "\x2a\x56" => "#i", # ��
		 "\x2a\x6c" => "#u", # ��
		 "\x2a\x50" => "#e", # ��
		 "\x2a\x5e" => "#o", # ��
		 "\x22\x31" => "\x21\x21" # ��
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
	$kanji =~ s/[\x30-\x7e][\xa1-\xfe]/\x21\x21/;
	$kanji =~ s/[\x29-\x2f][\x21-\x7e]/\x21\x21/;
	$kanji =~ s/[\x22][\x2f-\x68]/\x21\x21/;

	$str .= $kanji;
    }

    # ľ����ʸ�����������ʤξ�硢
    # ʿ��̾���ɲá�(��: ���ä���١�)
    # �ޥ��ʥ�(��: \x21\x5d)��Ĺ��(��: \x21\x3c)���᤹��
    $str =~ s/([\x24-\x25][\x21-\x76])\x21\x5d/$1\x21\x3c/g;

    # JIS X 0208-1978 ( JIS C 6328 97 ) escape sequence.
    return "\x1b\x24\x40$str\x1b\x28\x42";
}

sub register_data($$$$) {
    my ($hashref, $fid, $subid, $string) = @_;

    my $name = "$fid\$$subid";
    $name = "$fid" if ($subid eq '');
    
    if (defined $hashref->{$name}) {
	$hashref->{$name} .= " ".$string;
    } else {
	$hashref->{$name} = $string;
    }
}

sub parse_options() {
    Getopt::Long::config('bundling');
    GetOptions(
	       'O|outdir=s'	=> \$OUTDIR,
	       'B|bag'		=> \$BagOpt,
	       'd|debug'	=> \$DEBUG,
	       );
}

sub main {
    # read JAPAN/MARC data from stdin.
    my $contents = join('', <>);
    my @records = split(/\x1d/, $contents);
    
    my $t = new Convert::EBCDIC;

    debug_print("Total $#records records found.\n");

    parse_options();
    print "File output directory is ... $OUTDIR\n";

    foreach my $record (@records) {
	my %data = ();
	my $length = length $record;
	my $label = $t->toascii(substr($record, 0, 24));
	my @fields = split(/\x1e/, substr($record, 24));
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
#		print "$field_id  ".$t->toascii($field)."\n";
		register_data(\%data, $field_id, '', $t->toascii($field));
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
#			print "$field_id \$$sub_id  ".$t->toascii($subfield)."\n";
			register_data(\%data, $field_id, $sub_id, $t->toascii($subfield));
		    } elsif ($mode eq "2") {
#			print "$field_id \$$sub_id  \x1b\x24\x42".$subfield."\x1b\x28\x42\n";
			my $kanji = escape_kanji($subfield);
			#my $kanji = "\x1b\x24\x42$subfield\x1b\x28\x42";
			register_data(\%data, $field_id, $sub_id, $kanji);
		    } else {
			debug_print "mode recognized mismatch: $mode\n";
		    }
		}
	    }
#	    print "\n";
	}
	dc_write(%data);
#	print "\n";
    }
}

# �ºݤ�Dublin Core�ǡ�����񤭽Ф���
sub dc_write(%) {
    my (%data) = @_;

    my %DC_MAP = ('010$A' => 'Identifier',
		  '251$A' => 'Title',
		  '251$F' => 'Creator',
		  '270$B' => 'Publisher',
		  '101$A' => 'Language',
		  '270$D' => 'Date');

    # DC element names have to be lower case. (eg. title, not 'Title')
    my %DC_MAP2 = ('title' => ['251$A', '251$B', '251$D', # �����ȥ�
			       '252$A', '252$B', '252$D', # �����ȥ�
			       '253$A', '253$B', '253$D', # �����ȥ�
			       '254$A', '254$B', '254$D', # �����ȥ�
			       '255$A', '255$B', '255$D', # �����ȥ�
			       '256$A', '256$B', '256$D', # �����ȥ�
			       '257$A', '257$B', '257$D', # �����ȥ�
			       '258$A', '258$B', '258$D', # �����ȥ�
			       '259$A', '259$B', '259$D', # �����ȥ�
			       '280$A', '280$B', '280$D', '280$F', # �ѽ�̾
			       '281$A', '281$B', '281$D', '281$S', '281$T', '281$X', # ���꡼��
			       '282$A', '282$B', '282$D', '283$S', '282$T', '282$X', # ���꡼��
			       '283$A', '283$B', '283$D', '282$S', '283$T', '283$X', # ���꡼��
			       '291$A', '291$B', '291$D', # ¿����Τγƴ��Υ����ȥ�
			       '292$A', '292$B', '292$D', # ¿����Τγƴ��Υ����ȥ�
			       '293$A', '293$B', '293$D', # ¿����Τγƴ��Υ����ȥ�
			       '294$A', '294$B', '294$D', # ¿����Τγƴ��Υ����ȥ�
			       '295$A', '295$B', '295$D', # ¿����Τγƴ��Υ����ȥ�
			       '296$A', '296$B', '296$D', # ¿����Τγƴ��Υ����ȥ�
			       '297$A', '297$B', '297$D', # ¿����Τγƴ��Υ����ȥ�
			       '298$A', '298$B', '298$D', # ¿����Τγƴ��Υ����ȥ�
			       '299$A', '299$B', '299$D', # ¿����Τγƴ��Υ����ȥ�
			       '354$A', # �������ȥ���
			       '551$A', '551$X', # �����ȥ�ɸ��
			       '552$A', '552$X', # �����ȥ�ɸ��
			       '553$A', '553$X', # �����ȥ�ɸ��
			       '554$A', '554$X', # �����ȥ�ɸ��
			       '555$A', '555$X', # �����ȥ�ɸ��
			       '556$A', '556$X', # �����ȥ�ɸ��
			       '557$A', '557$X', # �����ȥ�ɸ��
			       '558$A', '558$X', # �����ȥ�ɸ��
			       '559$A', '559$X', # �����ȥ�ɸ��
			       '580$A', '580$X', # �ѽ�̾ɸ��
			       '581$A', '581$X', # ���꡼���Υ����ȥ�ɸ��
			       '582$A', '582$X', # ���꡼���Υ����ȥ�ɸ��
			       '583$A', '583$X', # ���꡼���Υ����ȥ�ɸ��
			       '591$A', '591$X', # ¿����Τγƴ��Υ����ȥ�ɸ��
			       '592$A', '592$X', # ¿����Τγƴ��Υ����ȥ�ɸ��
			       '593$A', '593$X', # ¿����Τγƴ��Υ����ȥ�ɸ��
			       '594$A', '594$X', # ¿����Τγƴ��Υ����ȥ�ɸ��
			       '595$A', '595$X', # ¿����Τγƴ��Υ����ȥ�ɸ��
			       '596$A', '596$X', # ¿����Τγƴ��Υ����ȥ�ɸ��
			       '597$A', '597$X', # ¿����Τγƴ��Υ����ȥ�ɸ��
			       '598$A', '598$X', # ¿����Τγƴ��Υ����ȥ�ɸ��
			       '599$A', '599$X'  # ¿����Τγƴ��Υ����ȥ�ɸ��
			       ],
                   'creator' => ['251$F', # ��Ǥɽ��
				 '252$F', # ��Ǥɽ��
				 '253$F', # ��Ǥɽ��
				 '254$F', # ��Ǥɽ��
				 '255$F', # ��Ǥɽ��
				 '256$F', # ��Ǥɽ��
				 '257$F', # ��Ǥɽ��
				 '258$F', # ��Ǥɽ��
				 '259$F', # ��Ǥɽ��
				 '751$A', '751$B', '751$X', # ����ɸ��
				 '752$A', '752$B', '752$X', # ����ɸ��
				 '753$A', '753$B', '753$X', # ����ɸ��
				 '754$A', '754$B', '754$X', # ����ɸ��
				 '755$A', '755$B', '755$X', # ����ɸ��
				 '756$A', '756$B', '756$X', # ����ɸ��
				 '757$A', '757$B', '757$X', # ����ɸ��
				 '758$A', '758$B', '758$X', # ����ɸ��
				 '759$A', '759$B', '759$X'  # ����ɸ��
				 ],
                   'subject' => ['650$A', '650$B', '650$X', # �Ŀͷ�̾
				 '658$A', '658$B', '658$X', # ���̷�̾
				 '677$A', # NDCʬ�൭��
				 '685$A', '685$X' # NDCʬ�൭��(���ʡ����޻���)
				 ],
                   'description' => ['350$A', # ������
				     '377$A'  # ������
				     ],
                   'publisher' => ['270$B' # ���Ǽ�
				   ],
                   'contributor' => ['281$F', # ���꡼���˴ؤ�����Ǥɽ��
				     '282$F', # ���꡼���˴ؤ�����Ǥɽ��
				     '283$F', # ���꡼���˴ؤ�����Ǥɽ��
				     '291$F', # ¿����Τγƴ�����Ǥɽ��
				     '292$F', # ¿����Τγƴ�����Ǥɽ��
				     '293$F', # ¿����Τγƴ�����Ǥɽ��
				     '294$F', # ¿����Τγƴ�����Ǥɽ��
				     '295$F', # ¿����Τγƴ�����Ǥɽ��
				     '296$F', # ¿����Τγƴ�����Ǥɽ��
				     '297$F', # ¿����Τγƴ�����Ǥɽ��
				     '298$F', # ¿����Τγƴ�����Ǥɽ��
				     '299$F', # ¿����Τγƴ�����Ǥɽ��
				     '781$A', '781$B', '781$X', # ���꡼��������ɸ��
				     '782$A', '782$B', '782$X', # ���꡼��������ɸ��
				     '783$A', '783$B', '783$X', # ���꡼��������ɸ��
				     '791$A', '791$B', '791$X', # ¿����Τγƴ�����ɸ��
				     '792$A', '792$B', '792$X', # ¿����Τγƴ�����ɸ��
				     '793$A', '793$B', '793$X', # ¿����Τγƴ�����ɸ��
				     '794$A', '794$B', '794$X', # ¿����Τγƴ�����ɸ��
				     '795$A', '795$B', '795$X', # ¿����Τγƴ�����ɸ��
				     '796$A', '796$B', '796$X', # ¿����Τγƴ�����ɸ��
				     '797$A', '797$B', '797$X', # ¿����Τγƴ�����ɸ��
				     '798$A', '798$B', '798$X', # ¿����Τγƴ�����ɸ��
				     '799$A', '799$B', '799$X'  # ¿����Τγƴ�����ɸ��
				     ],
                   'date' => ['270$D' # ����ǯ��
                              ],
                   'type' => [],
                   'format' => [], # '275$A' ����(�����μ���) :: �ɤ��ؤ�뤫����???
                   'identifier' => [ # '001', :: �쥳���ɼ����ֹ� (�������ֹ��Ʊ��ʤΤǺ��)
				    '010$A', # ISBN
				    '020$B', # �������ֹ�
				    '905$A', # NDL���ᵭ��
				    '906$A'  # NDL�����ֹ�
				    ],
                   'source' => [],
                   'language' => ['101$A'  # ����θ���
                                  ],
                   'relation' => [],
                   'coverage' => ['270$A' # ������
				  ],
                   'rights' => []);

    my $DC_HEAD = <<EOF;
<?xml version="1.0" encoding="EUC-JP"?>
<rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
         xmlns:dc="http://purl.org/dc/elements/1.0/">

<rdf:Description about="">
EOF

    my $DC_FOOT = <<EOF;
</rdf:Description>
</rdf:RDF>
EOF

    my $fh = new IO::File;
    $fh->open("|nkf -e > $OUTDIR/$data{'001'}.rdf") || die "$data{'001'}: $!\n";
    print "open $data{'001'} ... ";

    print $fh $DC_HEAD;
#    foreach my $key (keys %data) {
#	if ($DC_MAP{$key}) {
#	    print $fh "  <dc:$DC_MAP{$key}>$data{$key}</dc:$DC_MAP{$key}>\n";
#	}
#    }

    foreach my $element (keys %DC_MAP2) {
	my @tmp = ();
	foreach my $field (@{$DC_MAP2{$element}}) {
	    if (defined $data{$field}) {
		# print "$element -> $field: $data{$field}\n";
		push @tmp, $data{$field};
	    } else {
		# This field cannot map to DC.
		# so, this field located to JPMARC original element.
		## print $fh "  <jpmarc:$field>$data{$field}</jpmarc:$field>\n";
		### This is !!mistake!!
		### �����򸫤Ƥ�DC�˥ޥåפ���Ƥʤ��ե�����ɤ�ʬ����ʤ���
	    }
	}
	if ($BagOpt) {
	    if ($#tmp == 0) {
		print $fh "  <dc:$element>$tmp[0]</dc:$element>\n";
	    } elsif ($#tmp > 0) {
		print $fh "  <dc:$element>\n";
		print $fh "   <rdf:Bag>\n";
		foreach my $item (@tmp) {
		    print $fh "    <rdf:li>$item</rdf:li>\n";
		}
		print $fh "   </rdf:Bag>\n";
		print $fh "  </dc:$element>\n";
	    } else {
		next;
	    }
	} else {
	    foreach my $item (@tmp) {
		print $fh "  <dc:$element>$item</dc:$element>\n";
	    }
	}
    }
    print $fh $DC_FOOT;

    $fh->close;
    print " done.\n";
}
