#
# ctors.t
#
# Test the constructors
#

use Test::More tests => 70;
use strict;
use Fcntl qw(O_CREAT S_IRWXU);
BEGIN { use_ok('POSIX::RT::Semaphore'); }

our $SEM = "/unlikely_to_exist.$$";

sub checkUnnamed($$) {
	my ($eval, $value) = @_;

	local $! = 0;
	my $sem = eval $eval;

	SKIP: {
		if (!$sem and $!{ENOSYS}) {
			skip "'$eval' unsupported", 4;
		}

		ok($sem, "$eval");
		isa_ok($sem, "POSIX::RT::Semaphore::Unnamed");
		ok($sem->getvalue == $value, "getvalue() == $value");
		ok($sem->destroy, "destroy()");
	}
}

sub checkNamed($$) {
	my ($eval, $value) = @_;

	local $! = 0;
	my $sem = eval $eval;

	SKIP: {
		if (!$sem and $!{ENOSYS}) {
			skip "'$eval' unsupported", 4;
		}

		ok($sem, "$eval");
		isa_ok($sem, "POSIX::RT::Semaphore::Named");
		ok($sem->getvalue == $value, "getvalue() == $value");
		ok($sem->close, "close()");
	}
}

checkUnnamed "POSIX::RT::Semaphore->init()", 1;
checkUnnamed "POSIX::RT::Semaphore->init(1)", 1;
checkUnnamed "POSIX::RT::Semaphore->init(0)", 1;
checkUnnamed "POSIX::RT::Semaphore->init(1, 7)", 7;
checkUnnamed "POSIX::RT::Semaphore->init(0, 7)", 7;
checkUnnamed "POSIX::RT::Semaphore::Unnamed->init(1)", 1;
checkUnnamed "POSIX::RT::Semaphore::Unnamed->init(0)", 1;
checkUnnamed "POSIX::RT::Semaphore::Unnamed->init(1, 7)", 7;
checkUnnamed "POSIX::RT::Semaphore::Unnamed->init(0, 7)", 7;

checkNamed "POSIX::RT::Semaphore->open('$SEM', O_CREAT, 0600, 1)", 1;
checkNamed "POSIX::RT::Semaphore->open('$SEM', O_CREAT, 0600)", 1;
checkNamed "POSIX::RT::Semaphore->open('$SEM', O_CREAT)", 1;
checkNamed "POSIX::RT::Semaphore->open('$SEM')", 1;
checkNamed "POSIX::RT::Semaphore::Named->open('$SEM', O_CREAT, 0600, 1)", 1;
checkNamed "POSIX::RT::Semaphore::Named->open('$SEM', O_CREAT, 0600)", 1;
checkNamed "POSIX::RT::Semaphore::Named->open('$SEM', O_CREAT)", 1;
checkNamed "POSIX::RT::Semaphore::Named->open('$SEM')", 1;

$! = 0;
my $ok = POSIX::RT::Semaphore->unlink($SEM);
SKIP: {
	unless (defined $ok) {
		skip "sem_unlink ENOSYS", 1 if $!{ENOSYS}; # cygwin?
		fail("sem_unlink: $!");
	}
	ok($ok, "sem_unlink");
}
