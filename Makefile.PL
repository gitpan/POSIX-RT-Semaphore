use 5.008;
use strict;
use warnings;
use ExtUtils::MakeMaker;
use DynaLoader;

my $SEMLIB = '-lrt';

# Advance "hints"
if ($^O eq 'linux') {
  $SEMLIB = '-lpthread';
} elsif ($^O eq 'darwin') {
  $SEMLIB = '-lc';
} elsif ($^O eq 'solaris') {
  # adapted from Time::HiRes
  require POSIX;
  my $osver = (POSIX::uname())[2];
  if (substr($osver, 2) <= 6) {
    $SEMLIB = '-lposix4';
  }
} else {
  for my $candidate (qw(-lc -lpthread -lc_r)) {
    next unless lib_has_symbol($candidate, 'sem_post');
    $SEMLIB = $candidate;
    last;
  }
}

WriteMakefile(
  'NAME'               => 'POSIX::RT::Semaphore',
  'AUTHOR'             => 'mjp <mjp@pilcrow.madison.wi.us>',
  'VERSION_FROM'       => 'Semaphore.pm',
  'CONFIGURE_REQUIRES' => { 'ExtUtils::MakeMaker' => 0,
                            'DynaLoader'          => 0 },
  'BUILD_REQUIRES'     => { 'Errno'               => 0,   # TEST_REQUIRES
                            'Fcntl'               => 0,
                            'Config'              => 0,
                            'Test::More'          => 0 },
  'PREREQ_PM'          => { 'XSLoader'            => 0,
                            'Config'              => 0,
                            'Exporter'            => 0 },
  'INC'                => '-I.',
  'LIBS'               => [$SEMLIB],
);

sub lib_has_symbol {
  my ($lib, $sym) = @_;

  $lib = "-l$lib" unless $lib =~ /^-l/;

  my $path = (DynaLoader::dl_findfile( $lib ))[0];
  return '' unless $path;
  my $libref = DynaLoader::dl_load_file($path);
  DynaLoader::dl_find_symbol($libref, $sym) if $libref;
}

