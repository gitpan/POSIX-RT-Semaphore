#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

#if !defined(_POSIX_SEMAPHORES)
#  error "POSIX::RT::Semaphore requires _POSIX_SEMAPHORES support."
#endif /* !defined(_POSIX_SEMAPHORES) */

#include <semaphore.h>
#include <errno.h>      /* ENOSYS */
#ifdef _POSIX_TIMEOUTS
#include <time.h>
#endif /* _POSIX_TIMEOUTS */

typedef int SysRet;

typedef struct PSem_C {
  sem_t* sem;
  char * name;
} * POSIX__RT__Semaphore___base;
typedef POSIX__RT__Semaphore___base POSIX__RT__Semaphore__Named;
typedef POSIX__RT__Semaphore___base POSIX__RT__Semaphore__Unnamed;

static struct PSem_C *
_psem_create(const char *name) {
	struct PSem_C *psem;
	Newz(0, psem, 1, struct PSem_C);
	if (name) psem->name = savepv(name);
	return psem;
}

static int
no_macro(char *s)
{
  croak("Your vendor has not defined the POSIX::RT::Semaphore macro %s", s);
  return -1;
}

static int
function_not_implemented(void)
{
  errno = ENOSYS;
  return -1;
}

#define sem_valid(sem)     ((sem) && (sem) != SEM_FAILED)

#define PRECOND_valid_psem(fname, psem)                   \
  do {                                                    \
    if (!psem || !sem_valid(psem->sem))                   \
        croak(fname "() method called on invalid psem");  \
  } while (0)


MODULE = POSIX::RT::Semaphore  PACKAGE = POSIX::RT::Semaphore  PREFIX = psem_
PROTOTYPES: DISABLE

BOOT:
{
	char * const pkgs[] = {
		"POSIX::RT::Semaphore::Named::ISA",
		"POSIX::RT::Semaphore::Unnamed::ISA",
	};
	int i;

	for (i = 0; i < sizeof(pkgs)/sizeof(*pkgs); i++) {
		AV *isa;
		isa = get_av(pkgs[i], TRUE);
		av_push(isa, newSVpv("POSIX::RT::Semaphore::_base", 0));
	}
}

PROTOTYPES: ENABLE
int
psem_SEM_VALUE_MAX()
    CODE:
#ifdef _POSIX_SEM_VALUE_MAX
    RETVAL = _POSIX_SEM_VALUE_MAX;
#else
    RETVAL = no_macro("SEM_VALUE_MAX");
#endif
    OUTPUT:
    RETVAL

int
psem_SEM_NSEMS_MAX()
    CODE:
#ifdef _POSIX_SEM_NSEMS_MAX
    RETVAL = _POSIX_SEM_NSEMS_MAX;
#else
    RETVAL = no_macro("SEM_NSEMS_MAX");
#endif
    OUTPUT:
    RETVAL

unsigned int
psem_SIZEOF_SEM_T()
	CODE:
	RETVAL = sizeof(sem_t);

	OUTPUT:
	RETVAL

SysRet
psem_unlink(pkg = "POSIX::RT::Semaphore", path)
	char*             pkg
	char*             path

	CODE:
#ifdef __CYGWIN__
	RETVAL = function_not_implemented();
#else
	RETVAL = sem_unlink(path);
#endif /* !__CYGWIN__ */

	OUTPUT:
	RETVAL

MODULE = POSIX::RT::Semaphore PACKAGE = POSIX::RT::Semaphore::_base  PREFIX = psem_
PROTOTYPES: DISABLE

void
psem_DESTROY(self)
	POSIX::RT::Semaphore::_base    self

	CODE:
	if (self->name && sem_valid(self->sem)) {
		if (sem_close(self->sem)) {
			croak("Error closing named semaphore during destruction\n");
			return;
		}
		Safefree(self->name);
	}
	Safefree(self);

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
#ifdef _POSIX_TIMEOUTS
	struct timespec ts;
#endif /* _POSIX_TIMEOUTS */

	CODE:
	PRECOND_valid_psem("timedwait", self);
#ifdef _POSIX_TIMEOUTS
	if (timeout < 0.0)
		timeout = 0.0;
	ts.tv_sec  = (long)timeout;
	timeout -= (NV)ts.tv_sec;
	ts.tv_nsec = (long)(timeout * 1000000000.0);
	RETVAL = sem_timedwait(self->sem, (const struct timespec *)&ts);
#else
	RETVAL = function_not_implemented();
#endif /* !_POSIX_TIMEOUTS */

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

	CODE:
	RETVAL = _psem_create(NULL);
	Newz(0, RETVAL->sem, 1, sem_t);
	if (sem_init(RETVAL->sem, pshared, value) == -1) {
		Safefree(RETVAL);
		XSRETURN_UNDEF;
	}
	#warn("xs.sem_init 0x%x (sem: 0x%x) thr_ct %d\n", RETVAL, RETVAL->sem, RETVAL->thr_ct);

	OUTPUT:
	RETVAL

SysRet
psem_destroy(self)
	POSIX::RT::Semaphore::Unnamed    self

	CODE:
	PRECOND_valid_psem("destroy", self);
	RETVAL = sem_destroy(self->sem);
	Safefree(self->sem);
	self->sem = SEM_FAILED;

	OUTPUT:
	RETVAL


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

	RETVAL = _psem_create(name);
	RETVAL->sem = sem;
	#warn("xs.sem_open 0x%x (sem: 0x%x) thr_ct %d\n", RETVAL, RETVAL->sem, RETVAL->thr_ct);

	OUTPUT:
	RETVAL

SysRet
psem_close(self)
	POSIX::RT::Semaphore::Named    self

	CODE:
	PRECOND_valid_psem("close", self);
	RETVAL = sem_close(self->sem);
	self->sem = SEM_FAILED;

	OUTPUT:
	RETVAL
