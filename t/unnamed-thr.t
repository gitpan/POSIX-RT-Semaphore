# UNNAMED (anonymous) semaphore tests under sems...

#########################

use threads;
use threads::shared;
use Test::More tests => 8;
use POSIX::RT::Semaphore;
use strict;

ok(1, "use ok");

my $sem = POSIX::RT::Semaphore->init(0, 1);

SKIP: {

  skip "sem_init(): $!", 10 unless $sem;

  ok($sem, "unnamed ctor");
  ok(!defined($sem->name), "nameless");
  ok($sem->getvalue() == 1, "getvalue == 1");
  async { $sem->post; } ->join;
  ok($sem->getvalue() == 2, "getvalue == 2");
  async { $sem->trywait; }->join;
  ok($sem->getvalue() == 1, "getvalue == 1");
  async { $sem->wait; }->join;
  ok($sem->getvalue() == 0, "getvalue == 0");

  my $j = threads->new(sub { return $sem->trywait; })->join;
  ok(!defined($j), "trywait");

}
