package POSIX::RT::Semaphore;

use 5.008;
BEGIN {
  $VERSION = '0.01';
  require XSLoader;
  XSLoader::load(__PACKAGE__, $VERSION);

  @EXPORT_OK = qw(SEM_NSEMS_MAX SEM_VALUE_MAX);
}

use strict;
use warnings;

sub import {
  require Exporter;
  goto &Exporter::import;
}

INIT {

  # -- threaded?
  #
  if ($threads::shared::threads_shared) {
    no warnings 'redefine';

    # --> ensure sem object is /shared/
    #
    foreach my $glob (*init, *open) {
      my $code = *{$glob}{CODE};
      next unless defined $code;
      *{$glob} = sub {
        my $sem;
        $sem = &$code;
        threads::shared::share($sem) if defined $sem;
        $sem;
      };
    }

    # --> ensure destructor invocation only upon DESTROY of final ref
    #
    my $dtor = \&DESTROY;
    *DESTROY = sub {
      return unless @_ and threads::shared::_refcnt($_[0]) == 1;
      &$dtor;
    };

  } # -- if $threads::shared::threads_shared

} # -- INIT 

1;
__END__

=head1 NAME

POSIX::RT::Semaphore - Perl interface to POSIX.1b semaphores

=head1 SYNOPSIS

  use threads;
  use threads::shared;
  use POSIX::RT::Semaphore;
  use Fcntl;            # O_CREAT, O_EXCL for named semaphore creation

  ## unnamed semaphore, inital value 1
  $sem = POSIX::RT::Semaphore->init(0, 1);

  ## named semaphore, initial value 1
  $nsem = POSIX::RT::Semaphore->open("/mysem", O_CREAT, 0660, 1);

  ## method synopsis

  $sem->wait;                             # down (P) operation
  ... protected section ...
  $sem->post;                             # up (V) operation

  if ($sem->trywait) {                    # non-blocking wait (trydown)
    ... protected section ...
    $sem->post;
  }

  $sem->timedwait(time() + 10);           # wait up to 10 seconds

=head1 DESCRIPTION

POSIX::RT::Semaphore provides a Perl interface to POSIX 1b Realtime
semaphores, as supported by your system.

POSIX::RT::Semaphore objects are handles to underlying system resources, much
as IO::Handle objects are handles to underlying system resources.

I<N.B.>: L<threads::shared|threads::shared> I<must> be L<use|perlfunc/use>d
before POSIX::RT::Semaphore is loaded, if any semaphore objects will be
visible to more than one thread.

=head1 METHODS

All functions return the undefined value on failure (setting $!), and true on
success.  A return value of zero is mapped to the true string "0 but true".

=head2 UNNAMED SEMAPHORES

=over 4

=item init PSHARED, VALUE

The C<init> class method returns a new, I<unnamed> semaphore object,
initialized to value VALUE.  If PSHARED is non-zero, the sem is shared between
processes (but see CAVEATS, below).

Unnamed sems are never implicitly destroyed -- the memory for the
POSIX::RT::Semaphore object is deallocated during DESTROY, but the underlying
system sem remains unless L</destroy> is invoked.

=item destroy

Invalidate the unnamed sem; future operations on it will fail.  This function
fails if other processes are blocked on the underlying semaphore.

Note that this is distinct from Perl's DESTROY.

=back

=head2 NAMED SEMAPHORES

=over 4

=item open NAME

=item open NAME, OFLAG

=item open NAME, OFLAG, MODE, VALUE

The C<open> class methods creates a new POSIX::RT::Semaphore object referring
to the underlying I<named> semaphore NAME.  Other processes may attempt to
access the same sem by that NAME.

OFLAG may specify O_CREAT and O_EXCL, imported from the L<Fcntl|Fcntl> module,
to create a new system semaphore.  In these cases, a filesystem-like MODE and
initial VALUE are needed.

=item close

Close the named semaphore for the calling process; future operations on the
object will fail.  The underlying sem, however, is not invalidated.

If not called explicitly, the semaphore is closed when its last reference goes
away.

=item unlink

This class method removes the named semaphore.  Analogous to unlinking a file,
this does not invalidate already open sems.

=back

=head2 GENERAL SEMAPHORE USE

=over 4

=item getvalue

Returns the current value of the semaphore, or, if the value is zero, a
negative number whose absolute value is the number of currently waiting
processes.

=item name

This method returns the object's associated name as set by L</open>, or undef
if created by L</init>.

=item post

Atomically increment the semaphore, allowing waiters to proceed if the new
counter value is greater than zero.

=item timedwait ABSOLUTE_TIMEOUT

Attempt to atomically decrement the semaphore, waiting until ABSOLUTE_TIMEOUT
before failing.

=item trywait

Atomically decrement the semaphore, failing immediately if the counter is at
or below zero.

=item wait

Atomically decrement the semaphore, blocking indefinitely until successful.

=back

=head1 CAVEATS

=over 4

=item ENOSYS AND WORSE

Implementation details vary; B<consult your system documentation>.

Interprocess semaphores may not be supported, for example, causing L</open> or
L</init> with a positive PSHARED value to return undef and set $! to "Function
not implemented".  Worse, PSHARED might mean "inherited across fork"
or "shared via shared memory."  In the latter case, you're out of luck, as
this module provides no means of supplying pre-shared memory to the L</init>
constructor.

Named semaphore semantics, specifically their relationship to filesystem
entities, is implementation defined.  POSIX conservatives will use only
pathname-like names with a single, leading slash (e.g., "/my_sem").

L</getvalue> may not support the special negative semantics.  B<consult your
system documentation>.

=item PERL ITHREADS

Presently under L<threads|threads>, objects are DESTROYed at every applicable
scope clearance in every thread, whether they are shared or unshared (that is,
copied) across threads.  This means that an object merely visible to a thread
will suffer destruction when that thread finishes, even if the object is alive
and well in other threads.

When L<threads::shared|threads::shared> is detected, POSIX::RT::Semaphore
plays tricks to ensure that its objects are DESTROYed only once, and then
only when appropriate.  See source for details.

=item MISC

wait/post are known by many names: down/up, acquire/release, P/V, and
lock/unlock (not to be confused with Perl's L<lock|perlfunc/lock> keyword) to
name a few.

=back

=head1 TODO

Attempted compilation in multiple environments (currently only
linux/LinuxThreads tested) and testing, testing, testing.

=head1 SEE ALSO

L<IPC::Semaphore>, L<Thread::Semaphore>

=head1 AUTHOR

Michael J. Pomraning

Please report bugs to E<lt>mjp-perl AT pilcrow.madison.wi.usE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2003 by Michael J. Pomraning

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself. 

=cut
