#
# use_consts.t
#
use Test::More tests => 4;
use strict;
BEGIN {
	our @consts = qw(SEM_NSEMS_MAX SEM_VALUE_MAX SIZEOF_SEM_T);
	use_ok('POSIX::RT::Semaphore', @consts);
}

our @consts;

for my $sym (@consts) {
	my $r;

	eval {
		no strict 'refs';
		$r = &{$sym}();
	};

	if (! $@) {
		pass("$sym (is $r)");
	} elsif ($@ =~ /Your vendor has not defined the/) {
		pass("$sym (not vendor-supplied)");
	} else {
		fail("$sym failure: $@");
	}
}
