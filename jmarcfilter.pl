#!/usr/local/bin/perl -w
#
# $Id$
#
# JAPAN/MARC�쥳���ɤ��ɤ�ǡ����쥳���ɣ��ե���������ˤ��롣

use strict;
$| = 1;

require 'jmarc.pl';

main();
sub main {
    my @tmp = <>;
    my $contents = join('', @tmp);
    my @records = jmarc::get_records($contents);
    
    # print("Total $#records records found.\n");
    foreach my $record (@records) {
	next if jmarc::get_status($record) eq $jmarc::DELETE;
	print jmarc::as_text($record);
	print "\n";
    }
}
