#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"
#include <errno.h>
#if !defined(_POSIX_SEMAPHORES)
#error "POSIX::RT::Semaphore requires _POSIX_SEMAPHORES support."
#endif
#include <semaphore.h>
#include <unistd.h>
#include <time.h>

/* 
 * Humorously, this XS is not threadsafe.  We leave it to the .pm to
 * keep track of sharedsv refcnt, permitting the DESTROY/dealloc routines
 * only when appropriate.
 */

typedef int     SysRet;
typedef struct POSIX__RT__Semaphore_s {
  sem_t* sem;
  char * name;
  unsigned char open;
} * POSIX__RT__Semaphore;

/* early impl. had SEM_FAILED as (sem_t *)-1 rather than NULL/whatever */
#define sem_valid(s)    ((s) && (s) != SEM_FAILED)

static POSIX__RT__Semaphore
psem_alloc(pTHX_ const char *name)
{
  /*
   *   named psem:  alloc name, not sem (sem_open() does that)
   * unnamed psem:  name is NULL, alloc sem
   *
   *   alloc psem in any case (of course)
   */
    POSIX__RT__Semaphore psem;
    Newz(0, psem, 1, struct POSIX__RT__Semaphore_s);
    if (name)
        psem->name = savepv(name);
    else
        Newz(0, psem->sem, 1, sem_t);
    return psem;
}

static void
psem_dealloc(pTHX_ POSIX__RT__Semaphore psem)
{
  /*
   * dealloc our psem as appropriate.  This does _not_ close/destroy
   * the sem_t (but see DESTROY).
   *
   *   named:  dealloc name, not sem (sem_close() does that)
   * unnamed:  name is NULL, dealloc sem
   *
   */
  if (psem->name)
      Safefree(psem->name);
  else
      if (sem_valid(psem->sem)) Safefree(aTHX_ psem->sem);

  Safefree(psem);
}

static int
no_macro(char *s)
{
  croak("Your vendor has not defined the POSIX::RT::Semaphore macro %s", s);
  return -1;
}

MODULE = POSIX::RT::Semaphore  PACKAGE = POSIX::RT::Semaphore  PREFIX = psem_
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

PROTOTYPES: DISABLE

void
psem_DESTROY(psem)
    POSIX::RT::Semaphore    psem
    CODE:

    /*   named: sem_close() if appropriate
     * unnamed: do /not/ sem_destroy()
     *
     *   dealloc in any case
     */

    if (psem->name && psem->open && sem_valid(psem->sem)) {
        sem_close(psem->sem);
        psem->open = 0;
    }

    psem_dealloc(aTHX_ psem);


POSIX::RT::Semaphore
psem_init(pkg = "POSIX::RT::Semaphore", pshared = 0, value = 1)
    char*               pkg
    int                 pshared
    unsigned            value
    CODE:
    RETVAL = psem_alloc(aTHX_ NULL);
    if (sem_init(RETVAL->sem, pshared, value) == -1) {
        psem_dealloc(aTHX_ RETVAL);
        RETVAL = 0;
    }
    OUTPUT:
    RETVAL

SysRet
psem_destroy(psem)
    POSIX::RT::Semaphore    psem
    CODE:
    if (psem->name) croak("Cannot destroy named semaphore");
    RETVAL = sem_destroy(psem->sem);
    OUTPUT:
    RETVAL

#define psem_name(psem)     ((psem)->name)
char*
psem_name(psem)
    POSIX::RT::Semaphore    psem

POSIX::RT::Semaphore
psem_open(pkg = "POSIX::RT::Semaphore", name, flags = 0, mode = 0666, value = 1)
    char*               pkg
    char*               name
    int                 flags
    Mode_t              mode
    unsigned            value
    CODE:
    RETVAL = psem_alloc(aTHX_ name);
    RETVAL->sem = sem_open(name, flags, mode, value);
    if (! sem_valid(RETVAL->sem)) {
        psem_dealloc(aTHX_ RETVAL);
        RETVAL = 0;
    }
    OUTPUT:
    RETVAL

SysRet
psem_close(psem)
    POSIX::RT::Semaphore    psem
    CODE:
    if (!psem->name) croak("Cannot close unnamed semaphore");
    RETVAL = sem_close(psem->sem);
    OUTPUT:
    RETVAL

#define psem_unlink(pkg, path)      sem_unlink(path)
SysRet
psem_unlink(pkg = "POSIX::RT::Semaphore", path)
    char*               pkg
    char*               path

#define psem_wait(psem)     sem_wait((psem)->sem)
SysRet
psem_wait(psem)
    POSIX::RT::Semaphore    psem

#define psem_trywait(psem)  sem_trywait((psem)->sem)
SysRet
psem_trywait(psem) 
    POSIX::RT::Semaphore    psem

SysRet
psem_timedwait(psem, timeout)
    POSIX::RT::Semaphore    psem
    NV                  timeout
    CODE:
#if defined _XOPEN_SOURCE && ((_XOPEN_SOURCE - 0) >= 600)
    {
    struct timespec ts;
    if (timeout < 0.0)
        timeout = 0.0;
    ts.tv_sec  = (long)timeout;
    timeout -= (NV)ts.tv_sec;
    ts.tv_nsec = (long)(timeout * 1000000000.0);
    Perl_warn(aTHX_ "errno: %d\n", errno);
    RETVAL = sem_timedwait(psem->sem, (const struct timespec *)&ts);
    Perl_warn(aTHX_ "errno: %d\n", errno);
    }
#else
    RETVAL = -1;
    errno = ENOSYS;
#endif
    OUTPUT:
    RETVAL

#define psem_post(psem)     sem_post((psem)->sem)
SysRet
psem_post(psem)
    POSIX::RT::Semaphore    psem

int
psem_getvalue(psem)
    POSIX::RT::Semaphore    psem
    PREINIT:
    int v;
    CODE:
    sem_getvalue(psem->sem, &v);
    RETVAL = v;
    OUTPUT:
    RETVAL

