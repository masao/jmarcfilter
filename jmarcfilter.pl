#!/usr/local/bin/perl -w

use strict;
use Convert::EBCDIC;

my $DEBUG = 1;
$| = 1;

&main();

sub debug_print($) {
    my ($str) = @_;

    if ($DEBUG) {
	print "$str";
    }
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
			print "$field_id \$$sub_id  \x1b\x24\x42".$subfield."\x1b\x28\x42\n";
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
