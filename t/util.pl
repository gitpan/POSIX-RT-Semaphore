#! /usr/bin/perl

# convenience functions for our tests

use Errno qw(ENOSYS);

sub is_implemented(&) {
	my $block = shift;
	local $! = 0;
	&$block;
	return $! != &ENOSYS;
}

sub zero_but_true($) { return ($_[0] and $_[0] == 0); }

1;
