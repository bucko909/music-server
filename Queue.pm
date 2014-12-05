package Queue;

use strict;
use warnings;
use Time::Local;
use Time::HiRes;
use LWP::Simple;
use POSIX qw/strftime/;
use DBI;

$ENV{HOME} = '/home/bucko';

sub new {
	my $this = {};
	bless $this;
	$this->get_dbi;
	return $this;
}

sub get_dbi {
	return $_[0]->{dbi} if exists $_[0]->{dbi};

	open MYCNF, "$ENV{HOME}/.my.cnf";
	local $/;
	my $contents = <MYCNF>;
	close MYCNF;
	my ($user, $database, $password);
	$user = $1 if $contents =~ /user = (.*)/;
	$database = $1 if $contents =~ /database = (.*)/;
	$password = $1 if $contents =~ /password = (.*)/;

	if (!$user || !$database || !$password) {
		&die_clean_fatal("Sorry, the .my.cnf file appears to be corrupt");
	}

	$_[0]->{dbi} = DBI->connect("dbi:mysql:database=$database", $user, $password);

	if (!$_[0]->{dbi}) {
		$_[0]->die_fatal_db("Sorry, I can't seem to connect to the database.");
	}

	return $_[0]->{dbi};
}

sub die_fatal {
	print STDERR "$0: Fatal error: $_[1]\n";
	print STDERR "$_[2]\n" if $_[2];
	$_[0]->db_do("UNLOCK TABLES"); # Potential loop if from DB error...
	exit 1;
}

sub die_fatal_db {
	$_[0]->die_fatal($_[1], "Database says: ".DBI->errstr);
}

sub die_fatal_permissions {
	$_[0]->die_fatal($_[1], "You don't have permission to do that!");
}

sub die_fatal_badinput {
	$_[0]->die_fatal($_[1], "Your input incomplete/invalid.");
}

sub db_do {
	my $this = shift @_;
	$this->{dbreqs}++;
	return $this->{dbi}->do(@_);
}

sub db_select {
	my $this = shift @_;
	$this->{dbreqs}++;
	return $this->{dbi}->selectall_arrayref(@_);
}

sub db_selectrow {
	my $this = shift @_;
	$this->{dbreqs}++;
	return $this->{dbi}->selectrow_arrayref(@_);
}

sub db_selectone {
	my $this = shift @_;
	my $row = $this->{dbi}->selectrow_arrayref(@_);
	$this->{dbreqs}++;
	return undef unless $row;
	return $row->[0];
}

sub lastid {
	my $this = shift @_;
	return $this->db_selectone("SELECT LAST_INSERT_ID();");
}

sub prefix { "queue_" }

sub next {
	my ($q) = @_;

	my $prefix = $q->prefix;

	$q->db_do("LOCK TABLES ${prefix}queue READ, ${prefix}playing WRITE");

	my $current = $q->db_selectrow("SELECT bracket, pos FROM ${prefix}playing");

	my $next;
	if ($current) {
		$next = $q->db_selectrow("SELECT bracket, pos, item FROM ${prefix}queue WHERE bracket > ? OR (bracket = ? AND pos > ?) ORDER BY bracket, pos LIMIT 1", {}, $current->[0], $current->[0], $current->[1]);

		if (!$next) {
			$q->db_do("UNLOCK TABLES");
			return;
		}
	} else {
		$next = $q->db_selectrow("SELECT bracket, pos, item FROM ${prefix}queue ORDER BY bracket, pos LIMIT 1");
		if (!$next) {
			$q->db_do("UNLOCK TABLES");
			return;
		}
	}

	$q->db_do("DELETE FROM ${prefix}playing");
	$q->db_do("INSERT INTO ${prefix}playing SET bracket = ?, pos = ?", {}, $next->[0], $next->[1]);

	$q->db_do("UNLOCK TABLES");

	return wantarray ? (@$next) : $next->[2];
}

sub insert {
	my ($q, $userid, $item) = @_;

	my $prefix = $q->prefix;

	$q->db_do("LOCK TABLES ${prefix}queue WRITE, ${prefix}playing READ");

	my ($bracket, $pos) = @{$q->db_selectrow("SELECT bracket, pos FROM ${prefix}playing") || [1, 0]};

	my $queued = $q->db_select("SELECT bracket FROM ${prefix}queue WHERE userid = ? AND bracket >= ?", {}, $userid, $bracket);

	my @queued = map { $_->[0] } @$queued;

	my $newbracket;
	if (!@queued) {
		$newbracket = $bracket;
	} else {
		my $temp = $queued[0];
		for (1..$#queued) {
			if ($queued[$_] > $temp + 1) {
				$newbracket = $temp + 1;
				last;
			}
			$temp = $queued[$_];
		}
		$newbracket = $queued[$#queued] + 1 if !$newbracket;
	}

	my $newpos = $q->db_selectone("SELECT MAX(pos) + 1 FROM ${prefix}queue WHERE bracket = ?", {}, $newbracket) || 1;

	$q->db_do("INSERT INTO ${prefix}queue SET bracket = ?, pos = ?, userid = ?, item = ?", {}, $newbracket, $newpos, $userid, $item);

	$q->db_do("UNLOCK TABLES");

	return wantarray ? ($newbracket, $newpos) : 1;
}

sub getuserid {
	my $q = shift;

	my $prefix = $q->prefix;

	my $host = $ENV{REMOTE_ADDR};
	return $q->db_selectone("SELECT userid FROM ${prefix}hosts WHERE ip = ?", {}, $host);
}

sub getusername {
	my ($q, $uid) = @_;

	my $prefix = $q->prefix;

	return $q->db_selectone("SELECT name FROM ${prefix}users WHERE id = ?", {}, $uid);
}

1;
