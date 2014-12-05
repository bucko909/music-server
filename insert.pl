#!/usr/bin/perl

use strict;
use warnings;
use Queue;

my $q = Queue->new();
my $prefix = $q->prefix;

my $user = $ARGV[0];
my $item = $ARGV[1];

if (!$user || !$item) {
	$q->die_fatal_badinput("No user/item given");
}

my $userid = $q->db_selectone("SELECT id FROM ${prefix}users WHERE name = ?", {}, $user);

if (!$userid) {
	$q->die_fatal_badinput("Invalid user given");
}

my ($bracket, $pos) = $q->insert( $userid, $item );

print "Inserted into bracket $bracket at position $pos\n";
