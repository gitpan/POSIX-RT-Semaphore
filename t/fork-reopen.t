#! /usr/bin/perl
#
# fork-reopen.t
#
# Can children manipulate sems by name?
#

use Test::More tests => 6;
use strict;
use Fcntl qw(O_CREAT);
BEGIN { require 't/util.pl'; }
BEGIN { use_ok('POSIX::RT::Semaphore'); }

use constant SEMNAME => "/unlikely_to_exist.$$";

sub child_sem($) {
	my $method = shift;
	my $pid;
	die "fork: $!\n" unless defined($pid = fork);

	if (!$pid) {
		my $sem = POSIX::RT::Semaphore->open(SEMNAME, O_CREAT, 0600, 0);
		$sem->$method;
		exit;
	}
	waitpid($pid, 0);
}

SKIP: {
	my $sem;

	skip "sem_open: ENOSYS", 5
		unless is_implemented {
			$sem = POSIX::RT::Semaphore->open(SEMNAME, O_CREAT, 0600, 0);
		};

	ok($sem, "sem_open");
	ok($sem->getvalue == 0, "getvalue == 0");
	$sem->post;
	ok($sem->getvalue == 1, "getvalue == 1");

	child_sem("post");
	child_sem("post");

	ok($sem->getvalue == 3, "getvalue == 3");
	child_sem("wait");
	ok($sem->getvalue == 2, "getvalue == 2");
}

