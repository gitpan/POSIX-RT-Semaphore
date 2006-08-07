# Taken from Time::HiRes
use POSIX qw(uname);
if (substr((uname())[2], 2) <= 6) {
	$self->{LIBS} = ['-lposix4'];
else {
	$self->{LIBS} = ['-lrt'];
}
