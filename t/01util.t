#! /usr/bin/perl
#
# 01util.t
#
# Make sure util.pl does what we want.
#

use Test::More tests => 8;
use Errno qw(ENOSYS ENXIO);
use strict;

BEGIN { require_ok("t/util.pl"); }

ok(defined \&is_implemented, "is_implemented defined");

my $v = undef;
$! = &ENXIO;

SKIP: {
	skip "expected skip", 1
		unless is_implemented { $v = "foo"; $! = &ENOSYS; };

	fail("fell through!");
} #-- SKIP

ok($v eq "foo", "$v was set");
ok($! == &ENXIO, "errno not altered");

SKIP: {
	skip "no skip", 1
		unless is_implemented { $v = "bar"; };

	pass("no skip supported");
}

ok($v eq "bar", "$v was set");
ok($! == &ENXIO, "errno not altered");
