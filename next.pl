#!/usr/bin/perl

use strict;
use warnings;
use Queue;

my $q = Queue->new();

my @next = $q->next();

if (!@next) {
	$q->die_fatal("Queue is exhauseted.");
}

print "$next[2]\n";
print STDERR "Queue is now at bracket $next[0], position $next[1]\n";
