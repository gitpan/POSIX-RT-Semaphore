# UNNAMED (anonymous) semaphore tests

#########################

use Test::More tests => 12;
use POSIX::RT::Semaphore;
use strict;

ok(1, "use ok");

my $sem = POSIX::RT::Semaphore->init(0, 1);

SKIP: {

  skip "sem_init(): $!", 10 unless $sem;

  ok($sem, "unnamed ctor");
  ok(!defined($sem->name), "nameless");
  ok($sem->getvalue() == 1, "getvalue == 1");
  ok($sem->wait(), "wait");
  ok($sem->getvalue() == 0, "getvalue == 0");
  ok(!defined($sem->trywait), "trywait EAGAIN");
  ok($sem->post && $sem->post, "post");
  ok($sem->getvalue == 2, "getvalue == 2");
  ok($sem->trywait, "trywait succeeds");
  ok($sem->getvalue == 1, "getvalue == 1");
  ok($sem->destroy, "destroy");

}

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

