# NAMED threaded semaphore tests

#########################

use threads;
use threads::shared;
use Test::More tests => 11;
use POSIX::RT::Semaphore;
use Fcntl qw(O_CREAT);
use strict;

ok(1, "use ok");

my $sem = POSIX::RT::Semaphore->open("/unlikely_to_be_extant_$$", O_CREAT, 0666, 1);

SKIP: {

  skip "sem_open(): $!", 10 unless $sem;

  ok($sem, "unnamed ctor");
  ok(!defined($sem->name), "nameless");
  ok($sem->getvalue() == 1, "getvalue == 1");
  async { ok($sem->wait(), "wait"); }->join;
  ok($sem->getvalue() == 0, "getvalue == 0");
  ok(!defined($sem->trywait), "trywait EAGAIN");
  async { ok($sem->post && $sem->post, "post"); }->join;
  ok($sem->getvalue == 2, "getvalue == 2");
  async { ok($sem->trywait, "trywait succeeds"); }->join;
  ok($sem->getvalue == 1, "getvalue == 1");

}

