#! /usr/bin/perl
#
# fork-inherit.t
#
# Can children manipulate our (named) sems?
#

use Test::More tests => 6;
use strict;
use Fcntl qw(O_CREAT);
BEGIN { require 't/util.pl'; }
BEGIN { use_ok('POSIX::RT::Semaphore'); }

use constant SEMNAME => "/unlikely_to_exist.$$";
local (*R, *W);

SKIP: {
	my $sem;

	skip "sem_open: ENOSYS", 2
		unless is_implemented {
			$sem = POSIX::RT::Semaphore->open(SEMNAME, O_CREAT, 0600, 0);
		};

	ok($sem, "sem_open");
	ok($sem->getvalue == 0, "getvalue == 0");

	die "pipe: $!\n" unless pipe(R, W);
	die "fork: $!\n" unless defined( my $pid = fork );

	if (!$pid) {
		close(R);
		$sem->post;
		exit;
	}

	close(W);
	<R>;
	ok($sem->getvalue == 1, "getvalue == 1");
	ok($sem->wait, "wait");
	ok($sem->getvalue == 0, "getvalue == 0");
}

