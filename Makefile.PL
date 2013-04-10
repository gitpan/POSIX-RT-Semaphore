use 5.008;
use strict;
use warnings;
use ExtUtils::MakeMaker;
use ExtUtils::CBuilder;
use Config;

my @MAYBES = ( '-lpthread', # most linux
               '-lrt',      # Many others (and, wrongly, many linux manpages)
               '-lposix4',  # solaris < 2.6
               '-lc' );     # darwin
my $SEMLIB;
my @DEFINE;

my %mm = (
  'NAME'               => 'POSIX::RT::Semaphore',
  'VERSION_FROM'       => 'Semaphore.pm',
  'BUILD_REQUIRES'     => { 'Errno'               => 0,   # TEST_REQUIRES
                            'Fcntl'               => 0,
                            'Config'              => 0,
                            'Test::More'          => 0 },
  'CONFIGURE_REQUIRES' => { 'ExtUtils::MakeMaker' => 0,
                            'ExtUtils::CBuilder'  => 0,
                            'Config'              => 0 },
  'PREREQ_PM'          => { 'XSLoader'            => 0,
                            'Config'              => 0,
                            'Exporter'            => 0 },
  'AUTHOR'             => 'mjp <mjp@pilcrow.madison.wi.us>',
  'INC'                => '-I.',
);

# -- Find the right library and test for a few specific features

$SEMLIB = canbuild(main => '(void)sem_post((sem_t *)0);',
                   libs => [@MAYBES]);
die "OS Unsupported - could not compile sem_post check" unless $SEMLIB;
print "Found sem_post in $SEMLIB\n";

# Older Cygwin
push @DEFINE, '-DHAVE_SEM_UNLINK'
  if canbuild(main => '(void)sem_unlink("/d");', libs => [$SEMLIB]);

# Some systems
push @DEFINE, '-DHAVE_SEM_TIMEDWAIT'
  if canbuild(inc  => '#include <time.h>',
              libs => [$SEMLIB],
              main => <<'_eotimedwait');
struct timespec ts;
(void)sem_timedwait((sem_t *)0, (const struct timespec *)&ts);
_eotimedwait


if ($SEMLIB eq '-lpthread' and $Config{ccname} eq 'gcc') {
  $mm{CC} = "$Config{cc} -pthread";
  $mm{LD} = "$Config{ld} -pthread";
  undef $SEMLIB;
}

$mm{LIBS}   = $SEMLIB if $SEMLIB;
$mm{DEFINE} = join ' ' => @DEFINE;
WriteMakefile( %mm );

#----------

# See if our sem test program compiles and links, returning the name of
# the linking library upon success.
sub canbuild {
  no warnings 'uninitialized';
  my %args = @_;
  my $inc  = delete $args{inc};
  my $main = delete $args{main};
  my $libs = delete $args{libs};
  my $ret;

  if (my @err = keys(%args)) {
    die "Unexpected params to canbuild: @err";
  }

  my $src_file = 'test_semlink.c';
  {
    open my $fh, '>', $src_file or die "Unable to open '$src_file'\n";
    print $fh <<__EOTEST;
#include <semaphore.h>
$inc
int main(int argc, char *argv[]) {
  $main
  (void)argc; (void)argv;
  return 0;
}
__EOTEST
  }
  my $cb = ExtUtils::CBuilder->new(quiet=>1);
  my $obj_file = eval { $cb->compile(source => $src_file) };
  die "OS unsupported - cannot compile test program $@" unless $obj_file;

  my @link_files;
  for my $l (@$libs) {
    @link_files = eval { $cb->link_executable(objects => $obj_file,
                                              extra_linker_flags => $l) };
    next unless @link_files;
    $ret = $l;
    last;
  }
  unlink grep defined, $src_file, $obj_file, @link_files;

  $ret;
}
