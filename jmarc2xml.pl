#!/usr/local/bin/perl -w
#
# $Id$
#
# JAPAN/MARCレコードを読んで、XML形式にする。

use strict;
require 'jmarc.pl';

$| = 1;

main();
sub main {
    my @tmp = <>;
    my $contents = join('', @tmp);
    my @records = jmarc::get_records($contents);
    
    print "<?xml version=\"1.0\" encoding=\"ISO-2022-JP\"?>\n";
    print "<jpmarc>\n";
    foreach my $record (@records) {
	# print "LABEL: ". jmarc::get_label($record) ."\n";
	my $stat = jmarc::get_status($record);
	my $type = jmarc::get_type($record);
	my %fields = jmarc::get_fields($record);
	print "<record status=\"$stat\" type=\"$type\">\n";
	foreach my $fid (sort keys %fields) {
	    if ($fid eq '001') {
		print " <field id=\"$fid\">$fields{$fid}</field>\n";
	    } else {
		print " <field id=\"$fid\">\n";
		foreach my $subfield (@{$fields{$fid}}) {
		    while (my ($sub_fid, $value) = each %{$subfield}) {
			print "  <subfield subid=\"$sub_fid\">";
			print $value;
			print "</subfield>\n";
		    }
		}
		print " </field>\n";
	    }
	}
	print "</record>\n\n";
    }
    print "</jpmarc>\n";
}
