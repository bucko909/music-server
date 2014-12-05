#!/usr/bin/perl

use strict;
use warnings;
use Queue;
use CGI;

my $c = Queue->new;
my $q = CGI->new;

print $q->header;
print $q->start_html;

my $username;
my $userid = $c->getuserid;
if ($userid) {
	$username = $c->getusername($userid);
} else {
	$username = "anonymous";
}
print "Hello, $username.";

print $q->end_html;
