#!/usr/local/bin/perl -w
# $Id$

# jmarc.pl: Japan/MARC レコード解析用のライブラリ。

# Copyright (C) 1998-2000 by Masao Takaku <masao@ulis.ac.jp>
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program; if not, write to the Free Software
#  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

# This file must be encoded in EUC-JP.

package jmarc;
use NKF;

### Global Variables
$RecordSep = '\x1d';
$FieldSep = '\x1e';
$SubFieldSep = '\x1f';
$LabelLength = 24;

$NEW = 'N';
$DELETE = 'D';
$CHANGE = 'C';

# 外字をどのようなコードにするかを定義。
# FIXME: 一応、長音のローマ字形(a^i^u^e^o^, etc.)は通常のアルファベットに戻す。
%GAIJI = ("\x2a\x23" => "#A", # Ａ
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

sub get_records($) {
    my ($cont) = @_;
    my @records = split(/$RecordSep/, $cont);
    return @records;
}

sub get_label($) {
    my ($rec) = @_;
    return ebcdic2ascii(substr($rec, 0, $LabelLength));
}

sub get_directory($) {
    my ($rec) = @_;
    my $baseaddr = get_baseaddr($rec);
    return ebcdic2ascii(substr($rec, $LabelLength, $baseaddr-1 - $LabelLength));
}

sub get_data($) {
    my ($rec) = @_;
    return substr($rec, get_baseaddr($rec));
}

sub get_status($) {
    my ($rec) = @_;
    my $label = get_label($rec);
    return substr($label, 5, 1);
}

sub get_baseaddr($) {
    my ($rec) = @_;
    my $label = get_label($rec);
    return int substr($label, 12, 5);
}

sub get_jpno($) {
    my ($rec) = @_;
    my $data = get_data($rec);
    return ebcdic2ascii(substr($data, 0, 8));
}

sub get_type($) {
    my ($rec) = @_;
    my $label = get_label($rec);
    return substr($label, 6, 1);
}

sub read_record($$) {
    my ($filename, $position) = @_;
    open(MARC, $filename) || die "open fail MARC ($filename): $!";

    my $record = undef;
    seek MARC, $position, 0;
    read MARC, $record, 5 ||
        die "read fail MARC ($filename, $position): $!";
    my $length = int jmarc::ebcdic2ascii($record);
    
    seek MARC, $position, 0;
    read MARC, $record, $length-1 ||
        die "read fail MARC ($filename, $position): $!";
    close MARC;
    return $record;
}

sub get_fields($) {
    my ($rec) = @_;
    my $directory = get_directory($rec);
    my $data = get_data($rec);
    my %fields = ();
    while ($directory =~ s/^(\d{3})(\d{4})(\d{5})//) {
	my $field_id = $1;
	my $field_len = int $2;
	my $field_start = int $3;
	# print "ID: $field_id, Length: $field_len, Offset: $field_start\n";
	
	my $field = substr($data, $field_start, $field_len-1);
	if ($field !~ /^$SubFieldSep/) {
	    $fields{$field_id} = ebcdic2ascii($field);
	    next;
	}
	my @subfields = ();
	while ($field =~ s/^$SubFieldSep(.)(...)(.)//) {
	    my $sub_id = ebcdic2ascii($1);
	    my $sub_len = int ebcdic2ascii($2);
	    my $mode = ebcdic2ascii($3);
	    # print "SubID: $sub_id, Length: $sub_len, Mode: $mode\n";
	    my $fdata = substr($field, 0, $sub_len);
	    if ($mode eq "1") {
		push @subfields, {$sub_id => ebcdic2ascii($fdata)};
	    } elsif ($mode eq "2") {
		push @subfields, {$sub_id => escape_kanji($fdata)};
	    }
	    $field = substr($field, $sub_len);
	}
	$fields{$field_id} = [@subfields];
    }
    return %fields;
}

sub as_text($) {
    my ($rec) = @_;
    my $label = jmarc::get_label($rec);
    my $text = '';
    $text = "$label\n\n";

    my %fields = jmarc::get_fields($rec);
    foreach my $fid (sort keys %fields) {
	if ($fid eq "001") {
	    $text .= "$fid  $fields{$fid}\n";
	    next;
	}
	foreach my $subfield (@{$fields{$fid}}) {
	    while (my ($sub_fid, $value) = each %{$subfield}) {
		$text .= "$fid \$$sub_fid $value\n";
	    }
	}
    }
    return $text;
}

# FIXME: ハッシュでかすぎ…。
   %desc = ('status' => { 'N' => "新規レコード",
			  'D' => "削除レコード",
			  'C' => "訂正レコード" },
	    'type' => { 'A' => "言語資料で印刷物",
			'B' => "非刊行物",
			'E' => "地図資料",
			'G' => "映像資料",
			'H' => "マイクロ形態資料",
			'I' => "録音資料",
			'K' => "静止画資料",
			'L' => "コンピュータファイル",
			'T' => "視覚障害者用資料" },
	    '001' => "レコード識別番号",
	    '010' => { 'A' => "ISBN" },
	    '020' => { 'A' => "国名コード",
		       'B' => "全国書誌番号"},
	    '100' => { 'A' => "一般的処理データ" },
	    '101' => { 'A' => "テキストの言語",
		       'C' => "原文の言語" },
	    '251' => { 'A' => "本タイトル",
		       'B' => "タイトル関連情報",
		       'D' => "巻次など",
		       'F' => "責任表示",
		       'W' => "資料種別" },
	    '252' => { 'A' => "本タイトル",
		       'B' => "タイトル関連情報",
		       'D' => "巻次など",
		       'F' => "責任表示",
		       'W' => "資料種別" },
	    '253' => { 'A' => "本タイトル",
		       'B' => "タイトル関連情報",
		       'D' => "巻次など",
		       'F' => "責任表示",
		       'W' => "資料種別" },
	    '254' => { 'A' => "本タイトル",
		       'B' => "タイトル関連情報",
		       'D' => "巻次など",
		       'F' => "責任表示",
		       'W' => "資料種別" },
	    '255' => { 'A' => "本タイトル",
		       'B' => "タイトル関連情報",
		       'D' => "巻次など",
		       'F' => "責任表示",
		       'W' => "資料種別" },
	    '256' => { 'A' => "本タイトル",
		       'B' => "タイトル関連情報",
		       'D' => "巻次など",
		       'F' => "責任表示",
		       'W' => "資料種別" },
	    '257' => { 'A' => "本タイトル",
		       'B' => "タイトル関連情報",
		       'D' => "巻次など",
		       'F' => "責任表示",
		       'W' => "資料種別" },
	    '258' => { 'A' => "本タイトル",
		       'B' => "タイトル関連情報",
		       'D' => "巻次など",
		       'F' => "責任表示",
		       'W' => "資料種別" },
	    '259' => { 'A' => "本タイトル",
		       'B' => "タイトル関連情報",
		       'D' => "巻次など",
		       'F' => "責任表示",
		       'W' => "資料種別" },
	    '261' => { 'A' => "並列タイトル" },
	    '265' => { 'A' => "版表示など" },
	    '270' => { 'A' => "出版地",
		       'B' => "出版者",
		       'D' => "出版年月" },
	    '275' => { 'A' => "ページ数など",
		       'B' => "大きさ",
		       'E' => "付属資料" },
	    '280' => { 'A' => "叢書名",
		       'B' => "叢書番号",
		       'D' => "副叢書名",
		       'F' => "副叢書番号" },
	    '281' => { 'A' => "本シリーズ名",
		       'B' => "シリーズ関連情報",
		       'D' => "シリーズ番号",
		       'F' => "シリーズに関する責任表示",
		       'S' => "下位シリーズ名",
		       'X' => "シリーズのISSN" },
	    '282' => { 'A' => "本シリーズ名",
		       'B' => "シリーズ関連情報",
		       'D' => "シリーズ番号",
		       'F' => "シリーズに関する責任表示",
		       'S' => "下位シリーズ名",
		       'X' => "シリーズのISSN" },
	    '283' => { 'A' => "本シリーズ名",
		       'B' => "シリーズ関連情報",
		       'D' => "シリーズ番号",
		       'F' => "シリーズに関する責任表示",
		       'S' => "下位シリーズ名",
		       'X' => "シリーズのISSN" },
	    '291' => { 'A' => "各巻のタイトル",
		       'B' => "各巻のタイトル関連情報",
		       'D' => "各巻の巻次など",
		       'F' => "各巻の責任表示" },
	    '291' => { 'A' => "各巻のタイトル",
		       'B' => "各巻のタイトル関連情報",
		       'D' => "各巻の巻次など",
		       'F' => "各巻の責任表示" },
	    '292' => { 'A' => "各巻のタイトル",
		       'B' => "各巻のタイトル関連情報",
		       'D' => "各巻の巻次など",
		       'F' => "各巻の責任表示" },
	    '293' => { 'A' => "各巻のタイトル",
		       'B' => "各巻のタイトル関連情報",
		       'D' => "各巻の巻次など",
		       'F' => "各巻の責任表示" },
	    '294' => { 'A' => "各巻のタイトル",
		       'B' => "各巻のタイトル関連情報",
		       'D' => "各巻の巻次など",
		       'F' => "各巻の責任表示" },
	    '295' => { 'A' => "各巻のタイトル",
		       'B' => "各巻のタイトル関連情報",
		       'D' => "各巻の巻次など",
		       'F' => "各巻の責任表示" },
	    '296' => { 'A' => "各巻のタイトル",
		       'B' => "各巻のタイトル関連情報",
		       'D' => "各巻の巻次など",
		       'F' => "各巻の責任表示" },
	    '297' => { 'A' => "各巻のタイトル",
		       'B' => "各巻のタイトル関連情報",
		       'D' => "各巻の巻次など",
		       'F' => "各巻の責任表示" },
	    '298' => { 'A' => "各巻のタイトル",
		       'B' => "各巻のタイトル関連情報",
		       'D' => "各巻の巻次など",
		       'F' => "各巻の責任表示" },
	    '299' => { 'A' => "各巻のタイトル",
		       'B' => "各巻のタイトル関連情報",
		       'D' => "各巻の巻次など",
		       'F' => "各巻の責任表示" },
	    '350' => { 'A' => "一般注記" },
	    '354' => { 'A' => "翻訳の原タイトル" },
	    '360' => { 'A' => "装丁",
		       'B' => "税込み価格",
		       'C' => "本体価格" },
	    '377' => { 'A' => "内容注記" },
	    '386' => { 'A' => "ファイル内容注記" },
	    '387' => { 'A' => "システム要件注記" },
	    '551' => { 'A' => "タイトル標目: カタカナ形",
		       'X' => "タイトル標目: ローマ字形",
		       'B' => "タイトル標目: 漢字形(所在フィールド)",
		       'D' => "タイトル標目: 巻次などの読み" },
	    '552' => { 'A' => "タイトル標目: カタカナ形",
		       'X' => "タイトル標目: ローマ字形",
		       'B' => "タイトル標目: 漢字形(所在フィールド)",
		       'D' => "タイトル標目: 巻次などの読み" },
	    '553' => { 'A' => "タイトル標目: カタカナ形",
		       'X' => "タイトル標目: ローマ字形",
		       'B' => "タイトル標目: 漢字形(所在フィールド)",
		       'D' => "タイトル標目: 巻次などの読み" },
	    '554' => { 'A' => "タイトル標目: カタカナ形",
		       'X' => "タイトル標目: ローマ字形",
		       'B' => "タイトル標目: 漢字形(所在フィールド)",
		       'D' => "タイトル標目: 巻次などの読み" },
	    '555' => { 'A' => "タイトル標目: カタカナ形",
		       'X' => "タイトル標目: ローマ字形",
		       'B' => "タイトル標目: 漢字形(所在フィールド)",
		       'D' => "タイトル標目: 巻次などの読み" },
	    '556' => { 'A' => "タイトル標目: カタカナ形",
		       'X' => "タイトル標目: ローマ字形",
		       'B' => "タイトル標目: 漢字形(所在フィールド)",
		       'D' => "タイトル標目: 巻次などの読み" },
	    '557' => { 'A' => "タイトル標目: カタカナ形",
		       'X' => "タイトル標目: ローマ字形",
		       'B' => "タイトル標目: 漢字形(所在フィールド)",
		       'D' => "タイトル標目: 巻次などの読み" },
	    '558' => { 'A' => "タイトル標目: カタカナ形",
		       'X' => "タイトル標目: ローマ字形",
		       'B' => "タイトル標目: 漢字形(所在フィールド)",
		       'D' => "タイトル標目: 巻次などの読み" },
	    '559' => { 'A' => "タイトル標目: カタカナ形",
		       'X' => "タイトル標目: ローマ字形",
		       'B' => "タイトル標目: 漢字形(所在フィールド)",
		       'D' => "タイトル標目: 巻次などの読み" },
	    '580' => { 'A' => "叢書名標目: カタカナ形",
		       'B' => "叢書名標目: 漢字形(所在フィールド)",
		       'X' => "叢書名標目: ローマ字形",
		       'D' => "叢書番号の読み" },
	    '581' => { 'A' => "シリーズ名標目: カタカナ形",
		       'B' => "シリーズ名標目: 漢字形(所在フィールド)",
		       'X' => "シリーズ名標目: ローマ字形",
		       'D' => "シリーズ名標目: 巻次などの読み" },
	    '582' => { 'A' => "シリーズ名標目: カタカナ形",
		       'B' => "シリーズ名標目: 漢字形(所在フィールド)",
		       'X' => "シリーズ名標目: ローマ字形",
		       'D' => "シリーズ名標目: 巻次などの読み" },
	    '583' => { 'A' => "シリーズ名標目: カタカナ形",
		       'B' => "シリーズ名標目: 漢字形(所在フィールド)",
		       'X' => "シリーズ名標目: ローマ字形",
		       'D' => "シリーズ名標目: 巻次などの読み" },
	    '591' => { 'A' => "各巻の標目: カタカナ形",
		       'B' => "各巻の標目: 漢字形(所在フィールド)",
		       'X' => "各巻の標目: ローマ字形",
		       'D' => "各巻の標目: 巻次などの読み" },
	    '592' => { 'A' => "各巻の標目: カタカナ形",
		       'B' => "各巻の標目: 漢字形(所在フィールド)",
		       'X' => "各巻の標目: ローマ字形",
		       'D' => "各巻の標目: 巻次などの読み" },
	    '593' => { 'A' => "各巻の標目: カタカナ形",
		       'B' => "各巻の標目: 漢字形(所在フィールド)",
		       'X' => "各巻の標目: ローマ字形",
		       'D' => "各巻の標目: 巻次などの読み" },
	    '594' => { 'A' => "各巻の標目: カタカナ形",
		       'B' => "各巻の標目: 漢字形(所在フィールド)",
		       'X' => "各巻の標目: ローマ字形",
		       'D' => "各巻の標目: 巻次などの読み" },
	    '595' => { 'A' => "各巻の標目: カタカナ形",
		       'B' => "各巻の標目: 漢字形(所在フィールド)",
		       'X' => "各巻の標目: ローマ字形",
		       'D' => "各巻の標目: 巻次などの読み" },
	    '596' => { 'A' => "各巻の標目: カタカナ形",
		       'B' => "各巻の標目: 漢字形(所在フィールド)",
		       'X' => "各巻の標目: ローマ字形",
		       'D' => "各巻の標目: 巻次などの読み" },
	    '597' => { 'A' => "各巻の標目: カタカナ形",
		       'B' => "各巻の標目: 漢字形(所在フィールド)",
		       'X' => "各巻の標目: ローマ字形",
		       'D' => "各巻の標目: 巻次などの読み" },
	    '598' => { 'A' => "各巻の標目: カタカナ形",
		       'B' => "各巻の標目: 漢字形(所在フィールド)",
		       'X' => "各巻の標目: ローマ字形",
		       'D' => "各巻の標目: 巻次などの読み" },
	    '599' => { 'A' => "各巻の標目: カタカナ形",
		       'B' => "各巻の標目: 漢字形(所在フィールド)",
		       'X' => "各巻の標目: ローマ字形",
		       'D' => "各巻の標目: 巻次などの読み" },
	    '650' => { 'A' => "個人件名標目: カタカナ形",
		       'B' => "個人件名標目: 漢字形",
		       'X' => "個人件名標目: ローマ字形" },
	    '658' => { 'A' => "一般件名標目: カタカナ形",
		       'B' => "一般件名標目: 漢字形",
		       'X' => "一般件名標目: ローマ字形" },
	    '677' => { 'A' => "NDC分類記号",
		       'V' => "NDC版次" },
	    '685' => { 'A' => "NDL分類記号",
		       'X' => "ローマ字付分類記号" },
	    '751' => { 'A' => "著者標目: カタカナ形",
		       'B' => "著者標目: 漢字形",
		       'X' => "著者標目: ローマ字形" },
	    '752' => { 'A' => "著者標目: カタカナ形",
		       'B' => "著者標目: 漢字形",
		       'X' => "著者標目: ローマ字形" },
	    '753' => { 'A' => "著者標目: カタカナ形",
		       'B' => "著者標目: 漢字形",
		       'X' => "著者標目: ローマ字形" },
	    '754' => { 'A' => "著者標目: カタカナ形",
		       'B' => "著者標目: 漢字形",
		       'X' => "著者標目: ローマ字形" },
	    '755' => { 'A' => "著者標目: カタカナ形",
		       'B' => "著者標目: 漢字形",
		       'X' => "著者標目: ローマ字形" },
	    '756' => { 'A' => "著者標目: カタカナ形",
		       'B' => "著者標目: 漢字形",
		       'X' => "著者標目: ローマ字形" },
	    '757' => { 'A' => "著者標目: カタカナ形",
		       'B' => "著者標目: 漢字形",
		       'X' => "著者標目: ローマ字形" },
	    '758' => { 'A' => "著者標目: カタカナ形",
		       'B' => "著者標目: 漢字形",
		       'X' => "著者標目: ローマ字形" },
	    '759' => { 'A' => "著者標目: カタカナ形",
		       'B' => "著者標目: 漢字形",
		       'X' => "著者標目: ローマ字形" },
	    '781' => { 'A' => "シリーズ著者標目: カタカナ形",
		       'B' => "シリーズ著者標目: 漢字形",
		       'X' => "シリーズ著者標目: ローマ字形" },
	    '782' => { 'A' => "シリーズ著者標目: カタカナ形",
		       'B' => "シリーズ著者標目: 漢字形",
		       'X' => "シリーズ著者標目: ローマ字形" },
	    '783' => { 'A' => "シリーズ著者標目: カタカナ形",
		       'B' => "シリーズ著者標目: 漢字形",
		       'X' => "シリーズ著者標目: ローマ字形" },
	    '791' => { 'A' => "各巻の著者標目: カタカナ形",
		       'B' => "各巻の著者標目: 漢字形",
		       'X' => "各巻の著者標目: ローマ字形" },
	    '792' => { 'A' => "各巻の著者標目: カタカナ形",
		       'B' => "各巻の著者標目: 漢字形",
		       'X' => "各巻の著者標目: ローマ字形" },
	    '793' => { 'A' => "各巻の著者標目: カタカナ形",
		       'B' => "各巻の著者標目: 漢字形",
		       'X' => "各巻の著者標目: ローマ字形" },
	    '794' => { 'A' => "各巻の著者標目: カタカナ形",
		       'B' => "各巻の著者標目: 漢字形",
		       'X' => "各巻の著者標目: ローマ字形" },
	    '795' => { 'A' => "各巻の著者標目: カタカナ形",
		       'B' => "各巻の著者標目: 漢字形",
		       'X' => "各巻の著者標目: ローマ字形" },
	    '796' => { 'A' => "各巻の著者標目: カタカナ形",
		       'B' => "各巻の著者標目: 漢字形",
		       'X' => "各巻の著者標目: ローマ字形" },
	    '797' => { 'A' => "各巻の著者標目: カタカナ形",
		       'B' => "各巻の著者標目: 漢字形",
		       'X' => "各巻の著者標目: ローマ字形" },
	    '798' => { 'A' => "各巻の著者標目: カタカナ形",
		       'B' => "各巻の著者標目: 漢字形",
		       'X' => "各巻の著者標目: ローマ字形" },
	    '799' => { 'A' => "各巻の著者標目: カタカナ形",
		       'B' => "各巻の著者標目: 漢字形",
		       'X' => "各巻の著者標目: ローマ字形" },
	    '905' => { 'A' => "NDLの請求番号" },
	    '906' => { 'A' => "NDLの印刷カード番号" }
	    );

sub as_html($$) {
    my ($rec, $display) = @_;
    my $html = '';
    my $status = jmarc::get_status($rec);
    my $type = jmarc::get_type($rec);
    my $jpno = jmarc::get_jpno($rec);
    my %fields = jmarc::get_fields($rec);

    my $bgcolor = '#ffff00';
    $html = "<p>". $desc{'status'}{$status} .": JP$jpno</p>\n";
    if ($display =~ /full/i) {
	$html .= "<table>\n";
	$html .= "<tr><td bgcolor=\"$bgcolor\">レコード種別</td><td>". $desc{'type'}{$type} ."</td></tr>\n";
	foreach my $fid (sort keys %fields) {
	    if ($fid eq "001") {
		$html .= "<tr><td bgcolor=\"$bgcolor\">$desc{'001'}</td><td>$fields{$fid}</td>\n";
		next;
	    }
	    foreach my $subfield (@{$fields{$fid}}) {
		while (my ($sub_fid, $value) = each %{$subfield}) {
		    $html .= "<tr><td bgcolor=\"$bgcolor\">";
		    $html .= $desc{$fid}{$sub_fid};
		    $html .= "</td><td>". nkf('-e', $value) ."</td></tr>\n";
		}
	    }
	}
	$html .= "</table>\n";
    } else {
	$html .= "<dl><dt><font size=\"+1\">";
	foreach my $field251 (@{$fields{'251'}}) {
	    if (defined $field251->{'A'}) {
		$html .= nkf('-e', $field251->{'A'});
		last;
	    }
	}
	$html .= "</font>\n";
	$html .= "<dd>";
	foreach my $field251 (@{$fields{'251'}}) {
	    if (defined $field251->{'F'}) {
		$html .= nkf('-e',$field251->{'F'}) . "\n";
		last;
	    }
	}
	foreach my $field270 (@{$fields{'270'}}) {
	    if (defined $field270->{'B'}) {
		$html .= "(" . nkf('-e', $field270->{'B'}) . ")";
		last;
	    }
	}
	$html .= "</dl>\n";
    }
    return $html;
}

# JIS X 0208 漢字をエスケープコードを含めて返す。
# FIXME: 同時に、外字の処理も行なう。
sub escape_kanji($) {
    my ($data) = @_;

    my $str = '';
    while (length($data)) {
        die "Length is Odd.\n" if (length($data) == 1);
        my $kanji = substr($data, 0, 2);
        $data = substr($data, 2);
	$kanji = $GAIJI{$kanji} if defined $GAIJI{$kanji};

	# FIXME: その他の外字は全て全角空白にする。
        $kanji =~ s/[\x30-\x7e][\xa1-\xfe]/\x21\x21/;
        $kanji =~ s/[\x29-\x2f][\x21-\x7e]/\x21\x21/;
        $kanji =~ s/[\x22][\x2f-\x68]/\x21\x21/;

        $str .= $kanji;
    }

    # 直前の文字がカタカナ(or 平仮名)の場合、
    ## 例: データベース、あっかんべー etc.
    # マイナス(−: \x21\x5d)を長音(ー: \x21\x3c)に戻す。
    $str =~ s/([\x24-\x25][\x21-\x76])\x21\x5d/$1\x21\x3c/g;

    # JIS X 0207 （合成文字）などへの対応 ?
    # FIXME: 制御コードは全て削除しておく。
    $str =~ s/[\x1c][\x4e-\x53]//g;
    
    # FIXME: JIS X 0208-1978 ( JIS C 6328 97 ) escape sequence.
    return "\x1b\x24\x40$str\x1b\x28\x42";
}
 
my @e2a_table = (
'\000', '\001', '\002', '\003', '\004', '\005', '\006', '\007', 
'\010', '\011', '\012', '\013', '\014', '\015', '\016', '\017', 
'\020', '\021', '\022', '\023', '\024', '\025', '\026', '\027', 
'\030', '\031', '\032', '\033', '\034', '\035', '\036', '\037', 
'\040', '\041', '\042', '\043', '\044', '\045', '\046', '\047', 
'\050', '\051', '\052', '\053', '\054', '\055', '\056', '\057', 
'\060', '\061', '\062', '\063', '\064', '\065', '\066', '\067', 
'\070', '\071', '\072', '\073', '\074', '\075', '\076', '\077', 
' ',    '\101', '\102', '\103', '\104', '\105', '\106', '\107', 
'\110', '\111', '[',    '.',    '<',    '(',    '+',    '!', 
'&',    '\121', '\122', '\123', '\124', '\125', '\126', '\127', 
'\130', '\131', ']',    '\\',    '*',    ')',    ';',    '^', 
'-',    '/',    '\142', '\143', '\144', '\145', '\146', '\147', 
'\150', '\151', '|',    ',',    '%',    '_',    '>',    '?', 
'\160', '\161', '\162', '\163', '\164', '\165', '\166', '\167', 
'\170', '\'',   ':',    '#',    '@',    '`',    '=',    '"', 
'\200', 'a',    'b',    'c',    'd',    'e',    'f',    'g', 
'h',    'i',    '\212', '\213', '\214', '\215', '\216', '\217', 
'\220', 'j',    'k',    'l',    'm',    'n',    'o',    'p', 
'q',    'r',    '\232', '\233', '\234', '\235', '\236', '\237', 
'\240', '-',    's',    't',    'u',    'v',    'x',    'w', 
'y',    'z',    '\252', '\253', '\254', '\255', '\256', '\257', 
'\260', '\261', '\262', '\263', '\264', '\265', '\266', '\267', 
'\270', '\271', '\272', '\273', '\274', '\275', '\276', '\277', 
'{',    'A',    'B',    'C',    'D',    'E',    'F',    'G', 
'H',    'I',    '\312', '\313', '\314', '\315', '\316', '\317', 
'}',    'J',    'K',    'L',    'M',    'N',    'O',    'P', 
'Q',    'R',    '\332', '\333', '\334', '\335', '\336', '\337', 
'$',    '\341', 'S',    'T',    'U',    'V',    'W',    'X', 
'Y',    'Z',    '\352', '\353', '\354', '\355', '\356', '\357', 
'0',    '1',    '2',    '3',    '4',    '5',    '6',    '7', 
'8',    '9',    '\372', '\373', '\374', '\375', '\376', '\377'
);

sub ebcdic2ascii($) {
    my ($e) = @_;
    
    $e =~ s/([\000-\377])/$e2a_table[ord($1)]/g;

    return $e;
}

1;

__END__

# 以下は簡単なマニュアルです。

=head1 NAME

jmarc.pl - Japan/MARC library for perl

=head1 SYSNOPSYS

  require 'jmarc.pl';
  
  my @records = jmarc::get_records($contents);

  foreach my $record (@records) {
      next if jmarc::get_status($record) eq $jmarc::DELETE;
      my %fields = jmarc::get_fields($record);

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
      print "\n";
  }

=head1 DESCRIPTION

このモジュールは、国立国会図書館が配布しているJapan/MARCレコードを解析
するためのライブラリである。

=over 4

=item jmarc::get_records()

含まれている複数のレコードをリストで返す。

=item jmarc::read_record($file, $pos)

ファイル名と開始位置を元に一レコードを読み込んで返す。

=item jmarc::get_label()

レコードのラベル部分(固定長:24byte)を返す。

=item jmarc::get_directory()

ディレクトリの部分を返す。

=item jmarc::get_data()

実際の書誌データ部分を返す。

=item jmarc::get_status()

ラベルのうち、レコードの状況(新規・訂正・削除)を返す。

=item jmarc::get_baseaddr()

データ部の開始位置を返す。

=item jmarc::get_jpno()

JP番号を返す。

=item jmarc::get_type()

レコードの種別（印刷物・コンピュータファイルなど）を返す。

=item jmarc::get_fields()

レコードのフィールド構造を解析して、結果全体をハッシュで返す。

=item jmarc::as_html()


=back

以下は、文字コード変換機能を持つ関数である。

=over 4

=item jmarc::escape_kanji()

2バイト部を外字を考慮してISO-2022-JP文字列に変換して返す。

=item jmarc::ebcdic2ascii()

EBCDICコードをASCIIに変換する。

=back

=head1 COPYRIGHT

Copyright (C) 2000 Masao Takaku <masao@ulis.ac.jp>.
All rights reserved.

=cut
