#!/usr/local/bin/perl -w
# $Id$
#

use strict;
use Benchmark;

my $count = 5;
timethese($count, {
    'old' => 'system("jmarcfilter.pl 200001 > old")',
    'new' => 'system("jmarcfilter-fast.pl 200001 > new")'
    });
