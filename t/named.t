# _named_ semaphore tests

#########################

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
  ok($sem->wait(), "wait");
  ok($sem->getvalue() == 0, "getvalue == 0");
  ok(!defined($sem->trywait), "trywait EAGAIN");
  ok($sem->post && $sem->post, "post");
  ok($sem->getvalue == 2, "getvalue == 2");
  ok($sem->trywait, "trywait succeeds");
  ok($sem->getvalue == 1, "getvalue == 1");

}

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

