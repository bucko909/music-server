#!/usr/bin/perl

use strict;
use warnings;
use Queue;

my $q = Queue->new();
my $prefix = Queue->prefix();

my @create = (
	qq/CREATE TABLE ${prefix}queue (bracket INTEGER NOT NULL, pos INTEGER NOT NULL, userid INTEGER NOT NULL, item TEXT NOT NULL, PRIMARY KEY (bracket, pos), UNIQUE (bracket, userid), KEY (item(10)));/,
	qq/CREATE TABLE ${prefix}playing (bracket INTEGER NOT NULL, pos INTEGER NOT NULL)/,
	qq/CREATE TABLE ${prefix}users (id INTEGER AUTO_INCREMENT PRIMARY KEY, name TINYTEXT NOT NULL, pass_md5 TINYTEXT NOT NULL, UNIQUE(name(10)))/,
);

$q->db_do($_) foreach(@create);
