#
# 00-load.t
#

use Config;
use Test::More tests => 1;

BEGIN { use_ok('POSIX::RT::Semaphore'); }
diag <<__eodiag;

Testing POSIX::RT::Semaphore $POSIX::RT::Semaphore::VERSION
$^O ($Config{archname})
Perl $]
$^X

__eodiag
