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

# 出力ファイルのディレクトリ
my $OUTDIR = cwd();

# 複数の書誌項目をBagでContainer化するか?
## -B or --bag で制御する。
my $BagOpt = 0;

main();

sub debug_print($) {
    my ($str) = @_;

    if ($DEBUG) {
	print "$str";
    }
}

# JIS X 0208 漢字をエスケープコードを含めて返す。
# 同時に、外字の処理も行なう。
# 一応、長音のローマ字形(a^i^u^e^o^, etc.)はアルファベットに戻す。
sub escape_kanji($) {
    my ($data) = @_;
    my %GAIJI = ("\x2a\x23" => "#A", # Ａ
		 "\x2a\x2f" => "#I", # Ｉ
		 "\x2a\x39" => "#U", # Ｕ
		 "\x2a\x2b" => "#E", # Ｅ
		 "\x2a\x34" => "#O", # Ｏ
		 "\x2a\x43" => "#a", # ａ
		 "\x2a\x56" => "#i", # ｉ
		 "\x2a\x6c" => "#u", # ｕ
		 "\x2a\x50" => "#e", # ｅ
		 "\x2a\x5e" => "#o", # ｏ
		 "\x22\x31" => "\x21\x21" # ／
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

    # 直前の文字がカタカナの場合、
    # 平仮名も追加。(例: あっかんべー)
    # マイナス(−: \x21\x5d)を長音(ー: \x21\x3c)に戻す。
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

# 実際にDublin Coreデータを書き出す。
sub dc_write(%) {
    my (%data) = @_;

    my %DC_MAP = ('010$A' => 'Identifier',
		  '251$A' => 'Title',
		  '251$F' => 'Creator',
		  '270$B' => 'Publisher',
		  '101$A' => 'Language',
		  '270$D' => 'Date');

    # DC element names have to be lower case. (eg. title, not 'Title')
    my %DC_MAP2 = ('title' => ['251$A', '251$B', '251$D', # タイトル
			       '252$A', '252$B', '252$D', # タイトル
			       '253$A', '253$B', '253$D', # タイトル
			       '254$A', '254$B', '254$D', # タイトル
			       '255$A', '255$B', '255$D', # タイトル
			       '256$A', '256$B', '256$D', # タイトル
			       '257$A', '257$B', '257$D', # タイトル
			       '258$A', '258$B', '258$D', # タイトル
			       '259$A', '259$B', '259$D', # タイトル
			       '280$A', '280$B', '280$D', '280$F', # 叢書名
			       '281$A', '281$B', '281$D', '281$S', '281$T', '281$X', # シリーズ
			       '282$A', '282$B', '282$D', '283$S', '282$T', '282$X', # シリーズ
			       '283$A', '283$B', '283$D', '282$S', '283$T', '283$X', # シリーズ
			       '291$A', '291$B', '291$D', # 多巻ものの各巻のタイトル
			       '292$A', '292$B', '292$D', # 多巻ものの各巻のタイトル
			       '293$A', '293$B', '293$D', # 多巻ものの各巻のタイトル
			       '294$A', '294$B', '294$D', # 多巻ものの各巻のタイトル
			       '295$A', '295$B', '295$D', # 多巻ものの各巻のタイトル
			       '296$A', '296$B', '296$D', # 多巻ものの各巻のタイトル
			       '297$A', '297$B', '297$D', # 多巻ものの各巻のタイトル
			       '298$A', '298$B', '298$D', # 多巻ものの各巻のタイトル
			       '299$A', '299$B', '299$D', # 多巻ものの各巻のタイトル
			       '354$A', # 原タイトル注記
			       '551$A', '551$X', # タイトル標目
			       '552$A', '552$X', # タイトル標目
			       '553$A', '553$X', # タイトル標目
			       '554$A', '554$X', # タイトル標目
			       '555$A', '555$X', # タイトル標目
			       '556$A', '556$X', # タイトル標目
			       '557$A', '557$X', # タイトル標目
			       '558$A', '558$X', # タイトル標目
			       '559$A', '559$X', # タイトル標目
			       '580$A', '580$X', # 叢書名標目
			       '581$A', '581$X', # シリーズのタイトル標目
			       '582$A', '582$X', # シリーズのタイトル標目
			       '583$A', '583$X', # シリーズのタイトル標目
			       '591$A', '591$X', # 多巻ものの各巻のタイトル標目
			       '592$A', '592$X', # 多巻ものの各巻のタイトル標目
			       '593$A', '593$X', # 多巻ものの各巻のタイトル標目
			       '594$A', '594$X', # 多巻ものの各巻のタイトル標目
			       '595$A', '595$X', # 多巻ものの各巻のタイトル標目
			       '596$A', '596$X', # 多巻ものの各巻のタイトル標目
			       '597$A', '597$X', # 多巻ものの各巻のタイトル標目
			       '598$A', '598$X', # 多巻ものの各巻のタイトル標目
			       '599$A', '599$X'  # 多巻ものの各巻のタイトル標目
			       ],
                   'creator' => ['251$F', # 責任表示
				 '252$F', # 責任表示
				 '253$F', # 責任表示
				 '254$F', # 責任表示
				 '255$F', # 責任表示
				 '256$F', # 責任表示
				 '257$F', # 責任表示
				 '258$F', # 責任表示
				 '259$F', # 責任表示
				 '751$A', '751$B', '751$X', # 著者標目
				 '752$A', '752$B', '752$X', # 著者標目
				 '753$A', '753$B', '753$X', # 著者標目
				 '754$A', '754$B', '754$X', # 著者標目
				 '755$A', '755$B', '755$X', # 著者標目
				 '756$A', '756$B', '756$X', # 著者標目
				 '757$A', '757$B', '757$X', # 著者標目
				 '758$A', '758$B', '758$X', # 著者標目
				 '759$A', '759$B', '759$X'  # 著者標目
				 ],
                   'subject' => ['650$A', '650$B', '650$X', # 個人件名
				 '658$A', '658$B', '658$X', # 一般件名
				 '677$A', # NDC分類記号
				 '685$A', '685$X' # NDC分類記号(カナ・ローマ字付)
				 ],
                   'description' => ['350$A', # 一般注記
				     '377$A'  # 内容注記
				     ],
                   'publisher' => ['270$B' # 出版者
				   ],
                   'contributor' => ['281$F', # シリーズに関する責任表示
				     '282$F', # シリーズに関する責任表示
				     '283$F', # シリーズに関する責任表示
				     '291$F', # 多巻ものの各巻の責任表示
				     '292$F', # 多巻ものの各巻の責任表示
				     '293$F', # 多巻ものの各巻の責任表示
				     '294$F', # 多巻ものの各巻の責任表示
				     '295$F', # 多巻ものの各巻の責任表示
				     '296$F', # 多巻ものの各巻の責任表示
				     '297$F', # 多巻ものの各巻の責任表示
				     '298$F', # 多巻ものの各巻の責任表示
				     '299$F', # 多巻ものの各巻の責任表示
				     '781$A', '781$B', '781$X', # シリーズの著者標目
				     '782$A', '782$B', '782$X', # シリーズの著者標目
				     '783$A', '783$B', '783$X', # シリーズの著者標目
				     '791$A', '791$B', '791$X', # 多巻ものの各巻著者標目
				     '792$A', '792$B', '792$X', # 多巻ものの各巻著者標目
				     '793$A', '793$B', '793$X', # 多巻ものの各巻著者標目
				     '794$A', '794$B', '794$X', # 多巻ものの各巻著者標目
				     '795$A', '795$B', '795$X', # 多巻ものの各巻著者標目
				     '796$A', '796$B', '796$X', # 多巻ものの各巻著者標目
				     '797$A', '797$B', '797$X', # 多巻ものの各巻著者標目
				     '798$A', '798$B', '798$X', # 多巻ものの各巻著者標目
				     '799$A', '799$B', '799$X'  # 多巻ものの各巻著者標目
				     ],
                   'date' => ['270$D' # 出版年月
                              ],
                   'type' => [],
                   'format' => [], # '275$A' 形態(資料の種別) :: どこへやるか不明???
                   'identifier' => [ # '001', :: レコード識別番号 (全国書誌番号と同一なので削除)
				    '010$A', # ISBN
				    '020$B', # 全国書誌番号
				    '905$A', # NDL請求記号
				    '906$A'  # NDL印刷番号
				    ],
                   'source' => [],
                   'language' => ['101$A'  # 著作の言語
                                  ],
                   'relation' => [],
                   'coverage' => ['270$A' # 出版地
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
		### ここを見てもDCにマップされてないフィールドは分からない。
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
