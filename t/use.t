use Test::More tests => 3;
use POSIX::RT::Semaphore qw(SEM_NSEMS_MAX SEM_VALUE_MAX);
use strict;

ok(1, "use/import ok");

my ($const, $ok);

eval { $const = SEM_NSEMS_MAX(); };
$ok = ($const > 0) || ($@ =~ /Your vendor has not defined the/);
ok($ok, "SEM_NSEMS_MAX");

eval { $const = SEM_VALUE_MAX(); };
$ok = ($const > 0) || ($@ =~ /Your vendor has not defined the/);
ok($ok, "SEM_VALUE_MAX");

