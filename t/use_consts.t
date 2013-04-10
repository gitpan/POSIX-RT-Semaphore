#
# use_consts.t
#
use Test::More tests => 2;
use strict;
use POSIX::RT::Semaphore;

our $pkg = 'A';

our @optional  = qw(SEM_NSEMS_MAX
                    SEM_VALUE_MAX
                    _SC_SEM_NSEMS_MAX
                    _SC_SEM_VALUE_MAX);

sub is_exported {
  my $sym = shift;
  my $r;
  eval <<__EOEVAL;
    package Ad::Hoc::$pkg;
    POSIX::RT::Semaphore->import('$sym');
    \$r = defined(&$sym);
__EOEVAL
  $pkg++;
  $r;
}

ok(is_exported('SIZEOF_SEM_T'), "SIZEOF_SEM_T exported");
ok(! is_exported('BOGUS_SEM_CONSTANT'), "Bogus constant not exported");

diag "\n";
for my $sym (@optional) {
  
  diag("$sym: " . (is_exported($sym) ? 'defined' : 'absent'));
}
