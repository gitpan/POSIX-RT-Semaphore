#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

#include <unistd.h>     /* _POSIX, _SC_* */

#if !defined(_POSIX_SEMAPHORES)
#  error "POSIX::RT::Semaphore requires _POSIX_SEMAPHORES support."
#endif

#include <semaphore.h>
#include <limits.h>     /* _POSIX_SEM_* */
#include <errno.h>      /* ENOSYS */

#ifdef HAVE_SEM_TIMEDWAIT
#  include <time.h>
#endif


#ifdef HAS_MMAP
#  include <sys/mman.h>
#  if defined(MAP_ANON) && !defined(MAP_ANONYMOUS)
#    define MAP_ANONYMOUS     MAP_ANON
#  endif
#  ifndef MAP_ANONYMOUS
#    include <fcntl.h> /* open(..., O_RDWR) */
#  endif
#  ifndef MAP_HASSEMAPHORE
#    define MAP_HASSEMAPHORE  0
#  endif
#  ifndef MAP_FAILED
#    define MAP_FAILED        ((void *)-1)
#  endif
#endif

typedef int SysRet;

static const char * const SEM_ANON_PSHARED = "\0SEM_ANON_PSHARED";

typedef struct PSem_C {
  sem_t* sem;
  char * name; /* Overloaded with SEM_ANON_PSHARED */
} * POSIX__RT__Semaphore___base;
typedef POSIX__RT__Semaphore___base POSIX__RT__Semaphore__Named;
typedef POSIX__RT__Semaphore___base POSIX__RT__Semaphore__Unnamed;

#define sem_valid(sem)     ((sem) && (sem) != SEM_FAILED)

#define PRECOND_valid_psem(fname, psem)                   \
  do {                                                    \
    if (!psem || !sem_valid(psem->sem))                   \
        croak(fname "() method called on invalid psem");  \
  } while (0)


/* _alloc_sem()
 *
 * Return a new sem_t in shared memory (maybe), or NULL (_not_ SEM_FAILED)
 * on failure.
 */
static sem_t *
_alloc_sem(int pshared) {
	sem_t *sem = NULL;

	if (!pshared) {
		Newxz(sem, 1, sem_t);
	} else {
#ifdef HAS_MMAP
		int fd = -1;
		int prot_flags = PROT_READ|PROT_WRITE;
		int map_flags = MAP_SHARED|MAP_HASSEMAPHORE;

#	ifdef MAP_ANONYMOUS
		map_flags |= MAP_ANONYMOUS;
		sem = (sem_t *)mmap(NULL, sizeof(*sem), prot_flags, map_flags, fd, 0);
#	else
		if ((fd = open("/dev/zero", O_RDWR)) != -1) {
			sem = (sem_t *)mmap(NULL, sizeof(*sem), prot_flags, map_flags, fd, 0);
			close(fd);
		}
#	endif /* MAP_ANONYMOUS */
#else
		/* Hmm.  No mmap.  Options:
		 *  - Dodge with EPERM, as some BSD variants do for any pshared sem
		 *  - croak("don't know how to allocate shared memory")
		 *  - shmget/IPC_PRIVATE
		 *  - sem_open/O_EXCL + sem_unlink
 		 */
		croak("mmap not implemented, but currently needed for pshared semaphore memory allocation");
#endif /* HAS_MMAP */
	}

	return sem;
}

/* _dealloc_sem
 *
 * Free a sem_t we allocated.
 */
static void
_dealloc_sem(sem_t *sem, int pshared)
{
	int save_errno = errno;

	if (sem_valid(sem)) {
		if (pshared) {
			munmap((void *)sem, sizeof(sem_t));
		} else {
			Safefree(sem);
		}
	}

	errno = save_errno;
}

static int
function_not_implemented(void)
{
  errno = ENOSYS;
  return -1;
}

MODULE = POSIX::RT::Semaphore  PACKAGE = POSIX::RT::Semaphore  PREFIX = psem_
PROTOTYPES: DISABLE

BOOT:
{
  struct { char * const sym; int value; } constants[] = {
    { "SIZEOF_SEM_T", sizeof(sem_t) },
#ifdef _POSIX_SEM_VALUE_MAX
    { "SEM_VALUE_MAX", _POSIX_SEM_VALUE_MAX },
#endif
#ifdef _SC_SEM_VALUE_MAX
    { "_SC_SEM_VALUE_MAX", _SC_SEM_VALUE_MAX },
#endif
#ifdef _POSIX_SEM_NSEMS_MAX
    { "SEM_NSEMS_MAX", _POSIX_SEM_NSEMS_MAX },
#endif
#ifdef _SC_SEM_NSEMS_MAX
    { "_SC_SEM_NSEMS_MAX", _SC_SEM_NSEMS_MAX },
#endif
#ifdef SEM_NAME_LEN
    { "SEM_NAME_LEN", SEM_NAME_LEN },
#endif
#ifdef SEM_NAME_MAX
    { "SEM_NAME_MAX", SEM_NAME_MAX },
#endif
  };
	char * const pkgs[] = {
		"POSIX::RT::Semaphore::Named::ISA",
		"POSIX::RT::Semaphore::Unnamed::ISA",
	};
	HV *stash;
	AV *export_ok;
	int i;

	for (i = 0; i < sizeof(pkgs)/sizeof(*pkgs); i++) {
		AV *isa;
		isa = get_av(pkgs[i], TRUE);
		av_push(isa, newSVpv("POSIX::RT::Semaphore::_base", 0));
	}

	stash = gv_stashpvn("POSIX::RT::Semaphore", 20, TRUE);
	export_ok = get_av("POSIX::RT::Semaphore::EXPORT_OK", TRUE);
  for (i = 0; i < sizeof(constants)/sizeof(*constants); i++) {
    newCONSTSUB(stash, constants[i].sym, newSViv(constants[i].value));
    av_push(export_ok, newSVpv(constants[i].sym, 0));
  }
}

SysRet
psem_unlink(pkg = "POSIX::RT::Semaphore", path)
	char*             pkg
	char*             path

	CODE:
#ifdef HAVE_SEM_UNLINK
	RETVAL = sem_unlink(path);
#else
	# older versions of Cygwin
	(void)path;
	RETVAL = function_not_implemented();
#endif

	OUTPUT:
	RETVAL

MODULE = POSIX::RT::Semaphore PACKAGE = POSIX::RT::Semaphore::_base  PREFIX = psem_
PROTOTYPES: DISABLE

SysRet
psem_wait(self)
	POSIX::RT::Semaphore::_base    self

	CODE:
	PRECOND_valid_psem("wait", self);
	RETVAL = sem_wait(self->sem);

	OUTPUT:
	RETVAL

SysRet
psem_trywait(self)
	POSIX::RT::Semaphore::_base    self

	CODE:
	PRECOND_valid_psem("trywait", self);
	RETVAL = sem_trywait(self->sem);

	OUTPUT:
	RETVAL

SysRet
psem_timedwait(self, timeout)
	POSIX::RT::Semaphore::_base    self
	NV                             timeout

	PREINIT:
#ifdef HAVE_SEM_TIMEDWAIT
	struct timespec ts;
#endif

	CODE:
	PRECOND_valid_psem("timedwait", self);
#ifdef HAVE_SEM_TIMEDWAIT
	if (timeout < 0.0)
		timeout = 0.0;
	ts.tv_sec  = (long)timeout;
	timeout -= (NV)ts.tv_sec;
	ts.tv_nsec = (long)(timeout * 1000000000.0);
	RETVAL = sem_timedwait(self->sem, (const struct timespec *)&ts);
#else
	(void)timeout;
	RETVAL = function_not_implemented();
#endif

	OUTPUT:
	RETVAL

SysRet
psem_post(self)
	POSIX::RT::Semaphore::_base    self

	CODE:
	PRECOND_valid_psem("post", self);
	RETVAL = sem_post(self->sem);

	OUTPUT:
	RETVAL

int
psem_getvalue(self)
	POSIX::RT::Semaphore::_base    self

	CODE:
	# RETVAL is an int, _not_ a SysRet, since we preserve -1
	PRECOND_valid_psem("getvalue", self);
	if (sem_getvalue(self->sem, &RETVAL) != 0) {
		XSRETURN_UNDEF;
	}

	OUTPUT:
	RETVAL

 ## Obsolecent ##
char*
psem_name(self)
	POSIX::RT::Semaphore::_base    self

	CODE:
	PRECOND_valid_psem("name", self);
	RETVAL = self->name;

	OUTPUT:
	RETVAL


MODULE = POSIX::RT::Semaphore PACKAGE = POSIX::RT::Semaphore::Unnamed  PREFIX = psem_
PROTOTYPES: DISABLE

POSIX::RT::Semaphore::Unnamed
psem_init(pkg = "POSIX::RT::Semaphore::Unnamed", pshared = 0, value = 1)
	char*               pkg
	int                 pshared
	unsigned            value

	PREINIT:
	sem_t *sem = NULL;

	CODE:
	RETVAL = NULL;

	sem = _alloc_sem(pshared);
	if (NULL == sem) XSRETURN_UNDEF;

	if (0 == (sem_init(sem, pshared, value))) {
		Newxz(RETVAL, 1, struct PSem_C);
		RETVAL->sem = sem;
		if (pshared) RETVAL->name = (char *)SEM_ANON_PSHARED;
	} else {
		_dealloc_sem(sem, pshared);
		XSRETURN_UNDEF;
	}

	OUTPUT:
	RETVAL

SysRet
psem_destroy(self)
	POSIX::RT::Semaphore::Unnamed    self

	CODE:
	PRECOND_valid_psem("destroy", self);
	if (0 == (RETVAL = sem_destroy(self->sem))) {
		_dealloc_sem(self->sem, self->name == SEM_ANON_PSHARED);
		self->sem = NULL;
	}

	OUTPUT:
	RETVAL

void
psem_DESTROY(self)
	POSIX::RT::Semaphore::Unnamed    self

	CODE:
	# Safe to destroy private anon sem, since dtor wrapper will prevent this
	# from executing if any other threads hold refence to self.
	if (self->name != SEM_ANON_PSHARED && sem_valid(self->sem))
		(void)sem_destroy(self->sem);
	_dealloc_sem(self->sem, self->name == SEM_ANON_PSHARED);
	Safefree(self);

MODULE = POSIX::RT::Semaphore PACKAGE = POSIX::RT::Semaphore::Named  PREFIX = psem_
PROTOTYPES: DISABLE

POSIX::RT::Semaphore::Named
psem_open(pkg = "POSIX::RT::Semaphore::Named", name, flags = 0, mode = 0666, value = 1)
	char*               pkg
	char*               name
	int                 flags
	Mode_t              mode
	unsigned            value

	PREINIT:
	sem_t*              sem;

	CODE:
	sem = sem_open(name, flags, mode, value);
	if (SEM_FAILED == sem) {
		XSRETURN_UNDEF;
	}

	Newxz(RETVAL, 1, struct PSem_C);
	RETVAL->sem = sem;
	RETVAL->name = savepv(name);

	OUTPUT:
	RETVAL

SysRet
psem_close(self)
	POSIX::RT::Semaphore::Named    self

	CODE:
	PRECOND_valid_psem("close", self);
	RETVAL = sem_close(self->sem);
	self->sem = NULL;

	OUTPUT:
	RETVAL

void
psem_DESTROY(self)
	POSIX::RT::Semaphore::Named    self

	CODE:
	if (sem_valid(self->sem)) (void)sem_close(self->sem);
	Safefree(self);
