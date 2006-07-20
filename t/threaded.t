# UNNAMED (anonymous) semaphore tests under sems...

#########################

BEGIN {
	use Config;
	if (! $Config{useithreads}) {
		print "1..0 # Skip: Perl not compiled with 'useithreads'\n";
		exit(0);
	}
}
use threads;
use Fcntl qw(O_CREAT);
use Config;
use Test::More tests => 14;
BEGIN { require 't/util.pl'; }
use strict;

use_ok("POSIX::RT::Semaphore");

SKIP: {
	skip "unthreaded", 13 unless $Config{useithreads};

	SKIP: {
		my $sem;

		skip "sem_init: ENOSYS", 6
			unless is_implemented { $sem = POSIX::RT::Semaphore->init(0, 1); };

		ok($sem, "unnamed ctor");
		ok($sem->getvalue() == 1, "getvalue == 1");

		threads->create(sub { $sem->post; } )->join;
		ok($sem->getvalue() == 2, "getvalue == 2");

		threads->create(sub { $sem->trywait; })->join;
		ok($sem->getvalue() == 1, "getvalue == 1");
		
		threads->create(sub { $sem->wait; })->join;
		ok($sem->getvalue() == 0, "getvalue == 0");
		
		threads->create(sub { $_[0]->post }, $sem)->join;
		ok($sem->getvalue() == 1, "getvalue == 1");
	} #-- skip anon psem

	SKIP: {
		my $sem;
		my $SEMNAME = "/unlikely_to_exist.$$";
		
		skip "sem_open: ENOSYS", 7
			unless is_implemented { $sem = POSIX::RT::Semaphore->open($SEMNAME, O_CREAT, 0600, 1); };

		ok($sem, "named ctor");
		ok($sem->getvalue() == 1, "getvalue == 1");

		threads->create(sub { $sem->post; } )->join;
		ok($sem->getvalue() == 2, "getvalue == 2");

		threads->create(sub { $sem->trywait; })->join;
		ok($sem->getvalue() == 1, "getvalue == 1");
		
		threads->create(sub { $sem->wait; })->join;
		ok($sem->getvalue() == 0, "getvalue == 0");
		
		threads->create(sub { $_[0]->post }, $sem)->join;
		ok($sem->getvalue() == 1, "getvalue == 1");

		SKIP: {
			my $ok;
			skip "sem_unlink ENOSYS", 1
				unless is_implemented { $ok = POSIX::RT::Semaphore->unlink($SEMNAME); };
			ok($ok, "sem_unlink");
		}
	} #-- SKIP named psem
}
